use familiar_desktop::{Result, common::Hypr, desktop};
use serde_json::{Value, json};
use std::fs;
struct Fake {
    windows: Vec<Value>,
    calls: Vec<String>,
    fail_move: bool,
}
impl Hypr for Fake {
    fn command(&mut self, args: &[&str]) -> Result<String> {
        self.calls.push(args.join(" "));
        match args {
            ["-j", "clients"] => Ok(json!(self.windows).to_string()),
            ["-j", "monitors"] => Ok(json!([{"activeWorkspace":{"id":1}},{"activeWorkspace":{"id":2}}]).to_string()),
            ["-j", "activewindow"] => Ok(json!({"address":"0x1"}).to_string()),
            ["-j", "binds"] => Ok(json!([{"key":"W","modmask":64,"description":"Close window"},{"key":"X","modmask":5,"description":"<b>Literal</b>","submap":"resize"},{"key":"A"}]).to_string()),
            ["dispatch", cmd] => {
                if cmd.contains("window.move") {
                    if self.fail_move { return Err("fixture movement failure".into()); }
                    for c in &mut self.windows {
                        if cmd.contains(&format!("address:{}\"", c["address"].as_str().unwrap())) {
                            c["workspace"]["name"] = if cmd.contains("special:familiar-desktop") { json!("special:familiar-desktop") } else { json!("1") };
                        }
                    }
                }
                Ok("ok".into())
            },
            _ => Err("unexpected fixture command".into())
        }
    }
}
fn window(addr: &str, workspace: &str, id: i64, pid: u64) -> Value {
    json!({"address":addr,"pid":pid,"initialClass":"fixture","workspace":{"id":id,"name":workspace},"mapped":true})
}
fn fake() -> Fake {
    Fake {
        windows: vec![
            window("0x1", "1", 1, 100),
            window("0x2", "2", 2, 200),
            window("0x3", "special:minimized", -99, 300),
            window("0x4", "3", 3, 400),
        ],
        calls: vec![],
        fail_move: false,
    }
}
#[test]
fn hide_only_visible_regular_windows_and_restore() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("state.json");
    let mut h = fake();
    desktop::show_desktop("show", &p, "session", &mut h).unwrap();
    let j: Value = serde_json::from_slice(&fs::read(&p).unwrap()).unwrap();
    assert_eq!(j["windows"].as_array().unwrap().len(), 2);
    assert_eq!(h.windows[2]["workspace"]["name"], "special:minimized");
    assert_eq!(h.windows[3]["workspace"]["name"], "3");
    assert!(desktop::show_desktop("show", &p, "session", &mut h).is_err());
    desktop::show_desktop("restore", &p, "session", &mut h).unwrap();
    assert!(h.calls.iter().any(|s| s.contains("workspace=\"2\"")));
    let j: Value = serde_json::from_slice(&fs::read(&p).unwrap()).unwrap();
    assert!(j["windows"].as_array().unwrap().is_empty());
}
#[test]
fn interruption_keeps_journal_before_first_move_and_retry_recovers() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("state.json");
    let mut h = fake();
    h.fail_move = true;
    assert!(desktop::show_desktop("show", &p, "session", &mut h).is_err());
    assert!(p.exists());
    h.fail_move = false;
    // Simulate the compositor receiving a move immediately before the helper died.
    h.windows[0]["workspace"]["name"] = json!("special:familiar-desktop");
    desktop::show_desktop("restore", &p, "session", &mut h).unwrap();
    assert_eq!(h.windows[0]["workspace"]["name"], "1");
}
#[test]
fn failed_restore_retains_only_failed_windows() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("state.json");
    let mut h = fake();
    desktop::show_desktop("show", &p, "session", &mut h).unwrap();
    h.fail_move = true;
    assert!(desktop::show_desktop("restore", &p, "session", &mut h).is_err());
    h.fail_move = false;
    desktop::show_desktop("restore", &p, "session", &mut h).unwrap();
}
#[test]
fn restarted_session_cannot_replay_old_addresses() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("state.json");
    let mut h = fake();
    desktop::show_desktop("show", &p, "old", &mut h).unwrap();
    h.calls.clear();
    desktop::show_desktop("restore", &p, "new", &mut h).unwrap();
    assert!(!h.calls.iter().any(|s| s.starts_with("dispatch")));
}
#[test]
fn reused_addresses_and_manually_moved_windows_are_not_restored() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("state.json");
    let mut h = fake();
    desktop::show_desktop("show", &p, "session", &mut h).unwrap();
    h.calls.clear();
    h.windows[0]["pid"] = json!(999);
    h.windows[1]["workspace"]["name"] = json!("4");
    desktop::show_desktop("restore", &p, "session", &mut h).unwrap();
    assert!(!h.calls.iter().any(|s| s.starts_with("dispatch")));
}
#[test]
fn malformed_journal_fails_without_mutation() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("state.json");
    let mut h = fake();
    fs::write(&p,json!({"schemaVersion":1,"session":"session","windows":[{"address":"0x1;evil","pid":10,"workspace":"1"}]}).to_string()).unwrap();
    assert!(desktop::show_desktop("restore", &p, "session", &mut h).is_err());
    assert!(!h.calls.iter().any(|s| s.starts_with("dispatch")));
}
#[test]
fn quit_requests_all_same_process_windows_without_signals_or_class_matching() {
    let mut h = fake();
    h.windows.push(window("0x5", "1", 1, 100));
    desktop::quit_app("0x1", &mut h).unwrap();
    let closed: Vec<_> = h
        .calls
        .iter()
        .filter(|s| s.contains("window.close"))
        .collect();
    assert_eq!(closed.len(), 2);
    assert!(closed.iter().any(|s| s.contains("0x5")));
    assert!(desktop::quit_targets("0x999", &h.windows).is_err());
    assert!(desktop::quit_targets("0x1;kill", &h.windows).is_err());
}
#[test]
fn shortcuts_are_active_described_bindings_with_literal_text() {
    let result = desktop::shortcuts(&mut fake()).unwrap();
    assert_eq!(result["shortcuts"].as_array().unwrap().len(), 2);
    assert_eq!(result["shortcuts"][0]["keys"], "Super + W");
    assert_eq!(result["shortcuts"][1]["description"], "<b>Literal</b>");
    assert_eq!(result["shortcuts"][1]["submap"], "resize");
}
#[test]
fn force_quit_requires_explicit_confirmation() {
    assert!(desktop::execute(&["force-quit".into(), "0x1".into()]).is_err());
}
