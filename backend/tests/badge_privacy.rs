use familiar_desktop::common::{FILE_LIMIT, save_badges_from_reader};
use std::fs;

#[test]
fn invalid_or_oversized_stdin_preserves_existing_badges() {
    let home = tempfile::tempdir().unwrap();
    let valid = br#"{"counts":{"mail":3},"urgent":{}}"#;
    save_badges_from_reader(home.path(), &valid[..]).unwrap();
    let path = home
        .path()
        .join(".local/state/omarchy/familiar-desktop-badges.json");
    for invalid in [
        Vec::new(),
        b"not json".to_vec(),
        b"{}".to_vec(),
        vec![b' '; FILE_LIMIT + 1],
    ] {
        assert!(save_badges_from_reader(home.path(), &invalid[..]).is_err());
        assert_eq!(fs::read(&path).unwrap(), valid);
    }
}
