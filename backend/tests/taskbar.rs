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
