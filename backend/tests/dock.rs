use familiar_desktop::{
    Result,
    dock::{self, DockIpc},
};
use serde_json::{Value, json};
use std::{fs, path::PathBuf};
fn client(addr: &str, workspace: &str) -> Value {
    json!({"address":addr,"class":"firefox","workspace":{"name":workspace}})
}
fn s(values: &[&str]) -> Vec<String> {
    values.iter().map(|s| s.to_string()).collect()
}
#[test]
fn selectors_preserve_all_app_identifiers() {
    assert_eq!(
        dock::split_queries(&s(&[
            "firefox",
            "firefox.desktop",
            "/usr/bin/firefox",
            "0xDEADBEEF"
        ])),
        (
            s(&["firefox", "firefox.desktop", "/usr/bin/firefox"]),
            None,
            "0xdeadbeef".into()
        )
    );
}
#[test]
fn legacy_index_selectors_and_hex_like_app_names() {
    assert_eq!(
        dock::split_queries(&s(&["firefox", "--index=2"])),
        (s(&["firefox"]), Some(2), "".into())
    );
    assert_eq!(
        dock::split_queries(&s(&["firefox", "2"])),
        (s(&["firefox"]), Some(2), "".into())
    );
    assert_eq!(
        dock::split_queries(&s(&["deface", "facade"])),
        (s(&["deface", "facade"]), None, "".into())
    );
}
#[test]
fn address_wins_over_index_and_active() {
    let all = [
        client("0xAAA", "1"),
        client("0xBBB", "1"),
        client("0xCCC", "special:minimized"),
    ];
    let m = all.iter().collect::<Vec<_>>();
    assert_eq!(
        dock::pick_target(&m, &all, "0xbbb", Some(0), "0xaaa"),
        Some(&all[1])
    );
}
#[test]
fn index_active_and_visible_fallbacks() {
    let all = [
        client("0xCCC", "special:minimized"),
        client("0xAAA", "1"),
        client("0xBBB", "1"),
    ];
    let m = all.iter().collect::<Vec<_>>();
    assert_eq!(dock::pick_target(&m, &all, "", Some(2), ""), Some(&all[2]));
    assert_eq!(
        dock::pick_target(&m, &all, "0xffff", None, "0xbbb"),
        Some(&all[2])
    );
    assert_eq!(dock::pick_target(&m, &all, "", None, ""), Some(&all[1]));
    assert_eq!(
        dock::pick_target(&[&all[0]], &all, "", None, ""),
        Some(&all[0])
    );
    assert!(dock::pick_target(&[], &[], "", None, "").is_none());
}
#[test]
fn explicit_address_resolves_even_without_class_match() {
    let all = [client("0xAAA", "1")];
    assert_eq!(
        dock::pick_target(&[], &all, "0xaaa", None, ""),
        Some(&all[0])
    );
}
#[test]
fn desktop_names_support_spaces_and_desktop_suffix() {
    let t = tempfile::tempdir().unwrap();
    for name in ["My Custom App.desktop", "org.telegram.desktop.desktop"] {
        fs::write(t.path().join(name), "").unwrap();
    }
    let dirs = [t.path().into()];
    assert_eq!(
        dock::find_desktop("My Custom App", &dirs),
        Some("My Custom App.desktop".into())
    );
    assert_eq!(
        dock::find_desktop("My Custom App.desktop", &dirs),
        Some("My Custom App.desktop".into())
    );
    assert_eq!(
        dock::find_desktop("org.telegram.desktop", &dirs),
        Some("org.telegram.desktop.desktop".into())
    );
}
#[test]
fn unsafe_desktop_identifiers_are_rejected() {
    for id in [
        "/etc/passwd",
        "../app.desktop",
        "app\0name",
        "",
        ".",
        "..",
        "--help",
    ] {
        assert!(dock::find_desktop(id, &[PathBuf::from("/tmp")]).is_none());
    }
}
#[test]
fn reverse_dns_and_plain_terminal_identifiers() {
    for id in [
        "com.mitchellh.ghostty",
        "org.kde.konsole",
        "com.gexperts.tilix",
        "org.gnome.ptyxis",
        "com.raggesilver.blackbox",
        "ghostty",
        "foot",
        "kitty",
        "alacritty",
    ] {
        assert!(dock::is_terminal(id), "{id}");
    }
    for id in ["firefox", "org.mozilla.firefox", "org.gnome.Nautilus"] {
        assert!(!dock::is_terminal(id));
    }
}
#[test]
fn cli_titles_and_aliases() {
    for (title, app) in [
        ("nvim src/main.rs", "nvim"),
        ("foot -e vim", "nvim"),
        ("hx file", "helix"),
        ("btm", "bottom"),
        ("yazi - ~/Downloads", "yazi"),
        ("ordinary shell", ""),
    ] {
        assert_eq!(dock::extract_cli(title, None), app);
    }
}
#[test]
fn pwa_urls_paths_browser_variants_and_profile_isolation() {
    for (class, query) in [
        (
            "chrome-teams.microsoft.com__-Profile_1",
            "google-chrome-stable --profile-directory=\"Profile 1\" --app=\"https://teams.microsoft.com/\"",
        ),
        (
            "chrome-outlook.office.com__mail_-Profile_1",
            "google-chrome-stable --profile-directory=\"Profile 1\" --app=\"https://outlook.office.com/mail/\"",
        ),
        (
            "chrome-excel.cloud.microsoft__-Profile_1",
            "google-chrome-stable --profile-directory=\"Profile 1\" --app=\"https://excel.cloud.microsoft/\"",
        ),
        (
            "brave-teams.microsoft.com__-Default",
            "brave-browser --app=\"https://teams.microsoft.com/\"",
        ),
        (
            "msedge-teams.microsoft.com__-Default",
            "microsoft-edge --app=\"https://teams.microsoft.com/\"",
        ),
    ] {
        assert!(dock::match_pwa(class, query), "{class}");
    }
    let q = "google-chrome-stable --profile-directory=\"Profile 2\" --app=\"https://outlook.office.com/mail/\"";
    assert!(!dock::match_pwa(
        "chrome-outlook.office.com__mail_-Profile_1",
        q
    ));
    assert!(dock::match_pwa(
        "chrome-outlook.office.com__mail_-Profile_2",
        q
    ));
    assert!(dock::match_pwa(
        "chrome-outlook.office.com__mail_-Default",
        "google-chrome-stable --app=\"https://outlook.office.com/mail/\""
    ));
}
#[test]
fn pwa_app_ids_and_non_pwa_classes() {
    let q = "google-chrome-stable --profile-directory=Default --app-id=appgkjomdnhhdolojlpkjafpklojikld";
    assert!(dock::match_pwa(
        "chrome-appgkjomdnhhdolojlpkjafpklojikld-Default",
        q
    ));
    assert!(!dock::match_pwa(
        "chrome-appgkjomdnhhdolojlpkjafpklojikld-Profile_1",
        q
    ));
    assert!(!dock::match_pwa("foot", "foot -e nvim"));
    assert!(!dock::match_pwa("google-chrome", "google-chrome-stable"));
}
#[test]
fn exec_parsing_keeps_literal_arguments_without_shell_evaluation() {
    assert_eq!(
        dock::exec_argv("app --name \"space name\" %f %% '$HOME' '$(touch bad)'"),
        s(&["app", "--name", "space name", "%", "$HOME", "$(touch bad)"])
    );
    assert!(dock::exec_argv("app \"broken").is_empty());
}
#[test]
fn icons_prefer_svg_and_add_reverse_dns_suffixes() {
    let t = tempfile::tempdir().unwrap();
    for sub in ["hicolor/scalable/apps", "hicolor/256x256/apps"] {
        fs::create_dir_all(t.path().join(sub)).unwrap();
    }
    fs::write(t.path().join("hicolor/scalable/apps/org.app.Icon.svg"), "").unwrap();
    fs::write(t.path().join("hicolor/256x256/apps/org.app.Icon.png"), "").unwrap();
    let icons = dock::scan_icons(&[t.path().into()]);
    assert!(icons["org.app.icon"].as_str().unwrap().ends_with(".svg"));
    assert_eq!(icons["icon"], icons["org.app.icon"]);
}
#[derive(Default)]
struct Fake {
    calls: Vec<String>,
}
impl DockIpc for Fake {
    fn command(&mut self, cmd: &str) -> Result<String> {
        self.calls.push(cmd.into());
        Ok("ok".into())
    }
}
fn monitors() -> Vec<Value> {
    vec![json!({"focused":true,"activeWorkspace":{"name":"2"},"specialWorkspace":{"name":""}})]
}
#[test]
fn minimize_uses_address_and_focuses_sibling() {
    let clients = [client("0xAAA", "2"), client("0xBBB", "2")];
    let mut ipc = Fake::default();
    assert!(
        dock::operate(
            "minimize-instance",
            &s(&["firefox", "0xAAA"]),
            &clients,
            &monitors(),
            "0xaaa",
            &mut ipc
        )
        .unwrap()
    );
    assert!(ipc.calls[0].contains("special:minimized"));
    assert!(ipc.calls[0].contains("address:0xAAA"));
    assert!(ipc.calls[1].contains("address:0xBBB"));
}
#[test]
fn repeated_minimize_on_hidden_window_is_ignored() {
    let clients = [client("0xAAA", "special:minimized")];
    let mut ipc = Fake::default();
    dock::operate(
        "minimize-instance",
        &s(&["0xAAA"]),
        &clients,
        &monitors(),
        "",
        &mut ipc,
    )
    .unwrap();
    assert!(ipc.calls.is_empty());
}
#[test]
fn restore_moves_to_focused_workspace_then_focuses() {
    let clients = [client("0xAAA", "special:minimized")];
    let mut ipc = Fake::default();
    dock::operate(
        "activate-instance",
        &s(&["0xAAA"]),
        &clients,
        &monitors(),
        "",
        &mut ipc,
    )
    .unwrap();
    assert!(ipc.calls[0].contains("workspace = \"2\""));
    assert!(ipc.calls[1].contains("hl.dsp.focus"));
}
#[test]
fn active_unminimized_window_is_focused_without_move() {
    let clients = [client("0xAAA", "2")];
    let mut ipc = Fake::default();
    dock::operate(
        "activate-instance",
        &s(&["firefox"]),
        &clients,
        &monitors(),
        "",
        &mut ipc,
    )
    .unwrap();
    assert_eq!(ipc.calls.len(), 1);
    assert!(ipc.calls[0].contains("hl.dsp.focus"));
}
#[test]
fn terminal_dock_does_not_swallow_dedicated_cli_windows() {
    let clients = [
        json!({"address":"0xAAA","class":"foot","title":"nvim file","workspace":{"name":"2"}}),
        json!({"address":"0xBBB","class":"foot","title":"shell","workspace":{"name":"2"}}),
    ];
    let mut ipc = Fake::default();
    dock::operate(
        "activate-instance",
        &s(&["foot"]),
        &clients,
        &monitors(),
        "",
        &mut ipc,
    )
    .unwrap();
    assert!(ipc.calls[0].contains("0xBBB"));
    let mut ipc = Fake::default();
    dock::operate(
        "activate-instance",
        &s(&["nvim"]),
        &clients,
        &monitors(),
        "",
        &mut ipc,
    )
    .unwrap();
    assert!(ipc.calls[0].contains("0xAAA"));
}
#[test]
fn unsafe_addresses_never_reach_dispatch() {
    let mut ipc = Fake::default();
    assert!(
        dock::operate(
            "minimize-instance",
            &s(&["0xA; bad"]),
            &[],
            &monitors(),
            "",
            &mut ipc
        )
        .is_err()
    );
    assert!(ipc.calls.is_empty());
}
