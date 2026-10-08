use familiar_desktop::taskbar;
use serde_json::{Value, json};
use std::{fs, os::unix::fs::symlink};
fn fixture() -> (
    tempfile::TempDir,
    std::path::PathBuf,
    std::path::PathBuf,
    Value,
) {
    let dir = tempfile::tempdir().unwrap();
    let config = dir.path().join("shell.json");
    let state = dir.path().join("state");
    let value = json!({"version":1,"idle":{"lock":600},"bar":{"position":"top","transparent":true,"centerAnchor":"omarchy.clock","layout":{
        "left":[{"id":"omarchy.menu"},{"id":"omarchy.workspaces"}],
        "center":[{"id":"omarchy.clock","format":"HH:mm"},{"id":"omarchy.weather"}],
        "right":[{"id":"omarchy.tray"},{"id":"io.github.tcballard.familiar-desktop","custom":42},{"id":"omarchy.audio"}]}}});
    fs::write(&config, value.to_string()).unwrap();
    (dir, config, state, value)
}
fn read(path: &std::path::Path) -> Value {
    serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
}
#[test]
fn round_trip_and_restart_keep_all_widgets_and_settings() {
    let (_dir, config, state, original) = fixture();
    taskbar::change("enable", &config, &state).unwrap();
    let enabled = read(&config);
    assert_eq!(enabled["bar"]["position"], "bottom");
    assert_eq!(enabled["bar"]["layout"]["left"][2]["custom"], 42);
    assert_eq!(enabled["bar"]["layout"]["right"][2]["format"], "HH:mm");
    assert_eq!(enabled["bar"]["transparent"], true);
    assert_eq!(
        taskbar::change("status", &config, &state).unwrap()["mode"],
        "enable"
    );
    taskbar::change("enable", &config, &state).unwrap();
    taskbar::change("reset", &config, &state).unwrap();
    assert_eq!(read(&config), original);
    taskbar::change("reset", &config, &state).unwrap();
    assert_eq!(read(&config), original);
}
#[test]
fn reset_preserves_later_personal_changes_and_new_widget_settings() {
    let (_dir, config, state, _) = fixture();
    taskbar::change("enable", &config, &state).unwrap();
    let mut current = read(&config);
    current["bar"]["position"] = json!("left");
    current["bar"]["transparent"] = json!(false);
    current["idle"]["lock"] = json!(900);
    current["bar"]["layout"]["left"][2]["custom"] = json!(43);
    current["bar"]["layout"]["right"]
        .as_array_mut()
        .unwrap()
        .push(json!({"id":"new.widget"}));
    fs::write(&config, current.to_string()).unwrap();
    assert!(taskbar::change("enable", &config, &state).is_err());
    taskbar::change("reset", &config, &state).unwrap();
    let restored = read(&config);
    assert_eq!(restored["bar"]["position"], "left");
    assert_eq!(restored["bar"]["transparent"], false);
    assert_eq!(restored["idle"]["lock"], 900);
    assert_eq!(restored["bar"]["layout"]["right"][1]["custom"], 43);
    assert_eq!(restored["bar"]["layout"]["right"][3]["id"], "new.widget");
}
#[test]
fn custom_bars_invalid_layout_and_duplicate_entries_are_refused() {
    for kind in ["custom", "bad-layout", "duplicate"] {
        let (_dir, config, state, mut value) = fixture();
        match kind {
            "custom" => value["bar"]["id"] = json!("another.bar"),
            "bad-layout" => value["bar"]["layout"]["left"] = json!(null),
            _ => value["bar"]["layout"]["right"]
                .as_array_mut()
                .unwrap()
                .push(json!({"id":"io.github.tcballard.familiar-desktop"})),
        }
        fs::write(&config, value.to_string()).unwrap();
        assert!(taskbar::change("enable", &config, &state).is_err());
        assert_eq!(read(&config), value);
        assert!(!state.join("placement.json").exists());
    }
}
#[test]
fn interrupted_enable_is_recoverable_and_symlinks_are_refused() {
    let (dir, config, state, original) = fixture();
    taskbar::change("enable", &config, &state).unwrap();
    fs::write(&config, original.to_string()).unwrap(); // receipt persisted, config did not
    taskbar::change("reset", &config, &state).unwrap();
    assert_eq!(read(&config), original);
    let link = dir.path().join("link.json");
    symlink(&config, &link).unwrap();
    assert!(taskbar::change("enable", &link, &state).is_err());
    taskbar::change("enable", &config, &state).unwrap();
    fs::remove_file(state.join("placement.json")).unwrap();
    symlink(&config, state.join("placement.json")).unwrap();
    assert!(taskbar::change("reset", &config, &state).is_err());
}

#[test]
fn height_override_restores_existing_preferences_byte_for_byte() {
    for original in [
        "",
        "[font]\nbase-size = 14\n",
        "[bar]\nsize-horizontal = 30 # personal\ntext = 'white'\n[font]\nbase-size = 14\n",
        "[bar]\ntext = 'white'",
    ] {
        let (_dir, config, state, _) = fixture();
        let style = config.with_extension("toml");
        fs::write(&style, original).unwrap();
        taskbar::change("enable", &config, &state).unwrap();
        let installed = fs::read_to_string(&style).unwrap();
        assert!(installed.contains("size-horizontal = 48 # Familiar Windows taskbar"));
        taskbar::change("enable", &config, &state).unwrap();
        assert_eq!(fs::read_to_string(&style).unwrap(), installed);
        taskbar::change("reset", &config, &state).unwrap();
        assert_eq!(fs::read_to_string(style).unwrap(), original);
    }
}

#[test]
fn height_restore_preserves_later_font_and_height_edits() {
    for changed_height in [false, true] {
        let (_dir, config, state, _) = fixture();
        let style = config.with_extension("toml");
        fs::write(
            &style,
            "[bar]\nsize-horizontal = 30\n[font]\nbase-size = 12\n",
        )
        .unwrap();
        taskbar::change("enable", &config, &state).unwrap();
        let mut current = fs::read_to_string(&style)
            .unwrap()
            .replace("base-size = 12", "base-size = 16");
        if changed_height {
            current = current.replace(
                "size-horizontal = 48 # Familiar Windows taskbar",
                "size-horizontal = 56 # personal",
            );
        }
        fs::write(&style, current).unwrap();
        taskbar::change("reset", &config, &state).unwrap();
        let restored = fs::read_to_string(&style).unwrap();
        assert!(restored.contains("base-size = 16"));
        assert!(restored.contains(if changed_height {
            "size-horizontal = 56 # personal"
        } else {
            "size-horizontal = 30"
        }));
    }
}

#[test]
fn active_legacy_taskbar_acquires_height_and_retains_original_restore() {
    let (_dir, config, state, original) = fixture();
    taskbar::change("enable", &config, &state).unwrap();
    let mut receipt = read(&state.join("placement.json"));
    receipt.as_object_mut().unwrap().remove("style");
    fs::write(state.join("placement.json"), receipt.to_string()).unwrap();
    fs::remove_file(config.with_extension("toml")).unwrap();
    taskbar::change("enable", &config, &state).unwrap();
    assert!(
        fs::read_to_string(config.with_extension("toml"))
            .unwrap()
            .contains("size-horizontal = 48")
    );
    taskbar::change("reset", &config, &state).unwrap();
    assert_eq!(read(&config), original);
    assert_eq!(
        fs::read_to_string(config.with_extension("toml")).unwrap(),
        ""
    );
}

#[test]
fn unsafe_style_files_are_refused_before_moving_bar() {
    for content in [
        "[bar]\n[bar]\n",
        "[bar]\nsize-horizontal = 20\nsize-horizontal = 30\n",
    ] {
        let (_dir, config, state, original) = fixture();
        fs::write(config.with_extension("toml"), content).unwrap();
        assert!(taskbar::change("enable", &config, &state).is_err());
        assert_eq!(read(&config), original);
        assert!(!state.join("placement.json").exists());
    }
    let (dir, config, state, original) = fixture();
    let target = dir.path().join("personal.toml");
    fs::write(&target, "[font]\nbase-size = 12\n").unwrap();
    symlink(&target, config.with_extension("toml")).unwrap();
    assert!(taskbar::change("enable", &config, &state).is_err());
    assert_eq!(read(&config), original);
    assert_eq!(
        fs::read_to_string(target).unwrap(),
        "[font]\nbase-size = 12\n"
    );
}
