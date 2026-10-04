// Only disposable child processes created by this fixture can be targeted.
use std::{
    fs,
    os::unix::fs::PermissionsExt,
    process::{Command, Stdio},
    thread,
    time::Duration,
};
#[test]
fn confirmed_force_quit_targets_only_the_selected_process() {
    let t = tempfile::tempdir().unwrap();
    let mut target = Command::new("sleep")
        .arg("30")
        .stdout(Stdio::null())
        .spawn()
        .unwrap();
    let mut other = Command::new("sleep")
        .arg("30")
        .stdout(Stdio::null())
        .spawn()
        .unwrap();
    let fake = t.path().join("hyprctl");
    fs::write(&fake, format!("#!/bin/sh\nprintf '%s' '[{{\"address\":\"0x123\",\"pid\":{},\"initialClass\":\"fixture\"}}]'\n", target.id())).unwrap();
    fs::set_permissions(&fake, fs::Permissions::from_mode(0o755)).unwrap();
    let invoke = |confirm: bool| {
        let mut cmd = Command::new(env!("CARGO_BIN_EXE_familiar-desktop"));
        cmd.args(["desktop", "force-quit", "0x123"]);
        if confirm {
            cmd.arg("--confirm");
        }
        cmd.env("PATH", t.path()).output().unwrap()
    };
    let unconfirmed = invoke(false);
    assert!(!unconfirmed.status.success());
    assert!(target.try_wait().unwrap().is_none());
    let confirmed = invoke(true);
    let result = || {
        assert!(
            confirmed.status.success(),
            "{}",
            String::from_utf8_lossy(&confirmed.stdout)
        );
        for _ in 0..50 {
            if let Some(status) = target.try_wait().unwrap() {
                assert!(!status.success());
                return;
            }
            thread::sleep(Duration::from_millis(10));
        }
        panic!("Target child was not stopped");
    };
    // Reap/clean up both fixture processes even if the assertion fails.
    let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(result));
    let untouched = other.try_wait().unwrap().is_none();
    let _ = target.kill();
    let _ = target.wait();
    let _ = other.kill();
    let _ = other.wait();
    assert!(untouched);
    if let Err(payload) = outcome {
        std::panic::resume_unwind(payload);
    }
}
