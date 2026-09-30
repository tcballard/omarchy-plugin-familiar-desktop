use familiar_desktop::{common, dock};
use std::{
    fs,
    io::{Read, Write},
    os::unix::net::UnixListener,
    thread,
    time::{Duration, Instant},
};
#[test]
fn stdout_and_stderr_overflow_are_stopped_during_receive() {
    for fd in [1, 2] {
        let start = Instant::now();
        let args = vec![
            "-c".into(),
            format!("while :; do printf '%65536s' x >&{fd}; done"),
        ];
        let error = common::run("/bin/sh", &args, Duration::from_secs(3)).unwrap_err();
        assert!(error.contains("exceeded"), "{error}");
        assert!(start.elapsed() < Duration::from_secs(3));
    }
}
#[test]
fn deadline_kills_descendants_holding_pipes() {
    let t = tempfile::tempdir().unwrap();
    let marker = t.path().join("survived");
    let code = format!(
        "(sleep 0.5; touch {}) & sleep 5",
        common::shell_quote(&marker.to_string_lossy())
    );
    assert!(
        common::run("/bin/sh", &["-c".into(), code], Duration::from_millis(100))
            .unwrap_err()
            .contains("timed out")
    );
    thread::sleep(Duration::from_millis(600));
    assert!(!marker.exists());
}
#[test]
fn errors_are_bounded_and_success_output_is_preserved() {
    let error = common::run(
        "/bin/sh",
        &[
            "-c".into(),
            "printf '%1000s' x | tr ' ' e >&2; exit 1".into(),
        ],
        Duration::from_secs(2),
    )
    .unwrap_err();
    assert_eq!(error.len(), 300);
    assert_eq!(
        common::run("/bin/echo", &["ok".into()], Duration::from_secs(2)).unwrap(),
        "ok\n"
    );
}
#[test]
fn file_reads_are_bounded_reject_fifos_and_allow_theme_symlinks() {
    let t = tempfile::tempdir().unwrap();
    let path = t.path().join("settings.json");
    assert_eq!(common::read_json(&path).unwrap(), serde_json::json!({}));
    fs::write(&path, vec![b' '; common::FILE_LIMIT + 1]).unwrap();
    assert!(common::read_json(&path).unwrap_err().contains("exceeds"));
    fs::remove_file(&path).unwrap();
    let c = std::ffi::CString::new(path.as_os_str().as_encoded_bytes()).unwrap();
    assert_eq!(unsafe { libc::mkfifo(c.as_ptr(), 0o600) }, 0);
    assert!(
        common::read_json(&path)
            .unwrap_err()
            .contains("regular file")
    );
    fs::remove_file(&path).unwrap();
    let target = t.path().join("theme.json");
    fs::write(&target, "{\"schemaVersion\":1}").unwrap();
    std::os::unix::fs::symlink(&target, &path).unwrap();
    assert_eq!(common::read_json(&path).unwrap()["schemaVersion"], 1);
}
#[test]
fn socket_normal_response_is_collected() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("socket");
    let listener = UnixListener::bind(&p).unwrap();
    let server = thread::spawn(move || {
        let (mut s, _) = listener.accept().unwrap();
        let mut b = [0; 32];
        assert!(s.read(&mut b).unwrap() > 0);
        s.write_all(b"[]").unwrap();
    });
    assert_eq!(
        dock::socket_command(&p, "j/clients", Duration::from_secs(1), 1024).unwrap(),
        "[]"
    );
    server.join().unwrap();
}
#[test]
fn oversized_socket_response_is_rejected() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("socket");
    let listener = UnixListener::bind(&p).unwrap();
    let server = thread::spawn(move || {
        let (mut s, _) = listener.accept().unwrap();
        let mut b = [0; 32];
        assert!(s.read(&mut b).unwrap() > 0);
        let _ = s.write_all(&vec![b'x'; 8192]);
    });
    assert!(
        dock::socket_command(&p, "j/clients", Duration::from_secs(1), 4096)
            .unwrap_err()
            .contains("byte limit")
    );
    server.join().unwrap();
}
#[test]
fn stalled_socket_has_whole_operation_deadline() {
    let t = tempfile::tempdir().unwrap();
    let p = t.path().join("socket");
    let listener = UnixListener::bind(&p).unwrap();
    let server = thread::spawn(move || {
        let (_s, _) = listener.accept().unwrap();
        thread::sleep(Duration::from_millis(200));
    });
    let start = Instant::now();
    assert!(dock::socket_command(&p, "j/clients", Duration::from_millis(50), 1024).is_err());
    assert!(start.elapsed() < Duration::from_millis(150));
    server.join().unwrap();
}
#[test]
fn lua_values_remain_single_strings() {
    assert_eq!(
        common::lua("a\"; os.execute(\"bad\") --\n\\"),
        "\"a\\\"; os.execute(\\\"bad\\\") --\\010\\\\\""
    );
    assert_eq!(common::lua("Café"), "\"Café\"");
}
#[test]
fn badge_state_is_atomic_and_rejects_bad_shapes_and_oversize() {
    let t = tempfile::tempdir().unwrap();
    common::save_badges(t.path(), "{\"counts\":{\"mail\":2},\"urgent\":{}}").unwrap();
    let p = t
        .path()
        .join(".local/state/omarchy/familiar-desktop-badges.json");
    assert_eq!(common::read_json(&p).unwrap()["counts"]["mail"], 2);
    for raw in [
        "[]".to_string(),
        "{}".into(),
        "x".repeat(common::FILE_LIMIT + 1),
    ] {
        assert!(common::save_badges(t.path(), &raw).is_err());
    }
    assert_eq!(common::read_json(&p).unwrap()["counts"]["mail"], 2);
}
