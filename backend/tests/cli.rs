use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::PathBuf,
    process::{Command, Output},
};
struct Fixture {
    _temp: tempfile::TempDir,
    home: PathBuf,
    binary: PathBuf,
    tools: PathBuf,
    library: PathBuf,
}
impl Fixture {
    fn new() -> Self {
        let t = tempfile::tempdir().unwrap();
        let home = t.path().to_path_buf();
        let binary = home.join("plugin/bin/familiar-desktop");
        fs::create_dir_all(binary.parent().unwrap()).unwrap();
        fs::copy(env!("CARGO_BIN_EXE_familiar-desktop"), &binary).unwrap();
        fs::write(home.join("plugin/manifest.json"), "{}").unwrap();
        fs::create_dir_all(home.join(".config/hypr")).unwrap();
        fs::write(
            home.join(".config/hypr/looknfeel.lua"),
            "-- personal settings\n",
        )
        .unwrap();
        let library = home.join("hyprbars.so");
        fs::write(&library, "").unwrap();
        let tools = home.join("tools");
        fs::create_dir_all(&tools).unwrap();
        let fake = tools.join("hyprctl");
        fs::write(&fake,r#"#!/bin/sh
printf '%s\n' "$*" >> "$HOME/calls"
case "$*" in
 '-j plugin list') if [ -f "$HOME/loaded" ]; then printf '[{"name":"hyprbars"}]'; else printf '[]'; fi;;
 'plugin load '*) touch "$HOME/loaded"; printf ok;;
 'plugin unload '*) rm -f "$HOME/loaded"; printf ok;;
 'reload') if grep -q 'hl.plugin.load' "$HOME/.config/omarchy/familiar-titlebars/titlebars.lua"; then touch "$HOME/loaded"; else rm -f "$HOME/loaded"; fi; printf ok;;
 'configerrors') :;;
 '-j activewindow') printf '{"address":"0xABC"}';;
 *) printf ok;;
esac
"#).unwrap();
        fs::set_permissions(&fake, fs::Permissions::from_mode(0o755)).unwrap();
        Self {
            _temp: t,
            home,
            binary,
            tools,
            library,
        }
    }
    fn run(&self, args: &[&str]) -> Output {
        Command::new(&self.binary)
            .args(args)
            .env("HOME", &self.home)
            .env("XDG_CONFIG_HOME", self.home.join(".config"))
            .env("PATH", format!("{}:/usr/bin:/bin", self.tools.display()))
            .output()
            .unwrap()
    }
}
#[test]
fn executable_setup_apply_disable_remove_preserves_user_config() {
    let f = Fixture::new();
    let o = f.run(&[
        "titlebars",
        "setup",
        "--library",
        f.library.to_str().unwrap(),
        "--enable",
        "--style",
        "windows",
    ]);
    assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stdout));
    let o = f.run(&[
        "titlebars",
        "apply",
        "--owner",
        "200-new",
        "--mode",
        "windows",
    ]);
    assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stdout));
    let generated = f
        .home
        .join(".config/omarchy/familiar-titlebars/titlebars.lua");
    let s = fs::read_to_string(&generated).unwrap();
    assert!(s.contains("familiar-desktop' titlebars action close"));
    assert!(!s.contains("python"));
    let o = f.run(&["titlebars", "disable", "--owner", "300-new"]);
    assert!(o.status.success());
    assert!(
        !fs::read_to_string(&generated)
            .unwrap()
            .contains("hl.plugin.load")
    );
    let o = f.run(&["titlebars", "remove"]);
    assert!(o.status.success());
    assert_eq!(
        fs::read_to_string(f.home.join(".config/hypr/looknfeel.lua"))
            .unwrap()
            .trim(),
        "-- personal settings"
    );
    assert!(!generated.exists());
}
#[test]
fn executable_close_and_maximize_use_literal_addresses() {
    let f = Fixture::new();
    for name in ["close", "maximize"] {
        let o = f.run(&["titlebars", "action", name]);
        assert!(o.status.success());
    }
    let calls = fs::read_to_string(f.home.join("calls")).unwrap();
    assert!(calls.contains("address:0xABC"));
    assert!(calls.contains("hl.dsp.window.close"));
    assert!(calls.contains("hl.dsp.window.fullscreen"));
}
#[test]
fn executable_badges_save_and_usage_errors_have_bounded_json() {
    let f = Fixture::new();
    let o = f.run(&["badges", "save", "{\"counts\":{\"mail\":3},\"urgent\":{}}"]);
    assert!(o.status.success());
    let v: serde_json::Value = serde_json::from_slice(
        &fs::read(
            f.home
                .join(".local/state/omarchy/familiar-desktop-badges.json"),
        )
        .unwrap(),
    )
    .unwrap();
    assert_eq!(v["counts"]["mail"], 3);
    for args in [
        vec!["titlebars", "apply", "--wrong"],
        vec!["badges", "save", "bad"],
        vec!["dock", "unknown"],
    ] {
        let o = f.run(&args);
        assert!(!o.status.success());
        let v: serde_json::Value = serde_json::from_slice(&o.stdout).unwrap();
        assert_eq!(v["state"], "failed");
        assert!(v["message"].as_str().unwrap().chars().count() <= 300);
    }
}
