use familiar_desktop::{
    Result,
    common::Hypr,
    config_file::{self, GeneratedUpdate},
};
use std::{fs, path::PathBuf};

#[derive(Default)]
struct Desktop {
    calls: usize,
    edit_on_reload: Option<PathBuf>,
}
impl Hypr for Desktop {
    fn command(&mut self, args: &[&str]) -> Result<String> {
        self.calls += 1;
        if args == ["reload"] {
            if let Some(path) = self.edit_on_reload.take() {
                fs::write(path, "personal edit during reload\n").unwrap();
                return Err("reload failed".into());
            }
            return Ok("ok".into());
        }
        assert_eq!(args, ["-j", "configerrors"]);
        Ok("[\"\"]".into())
    }
}

struct Files {
    _dir: tempfile::TempDir,
    config: PathBuf,
    generated: PathBuf,
    backups: PathBuf,
}
impl Files {
    fn new(previous: Option<&str>) -> Self {
        let dir = tempfile::tempdir().unwrap();
        let config = dir.path().join("hyprland.lua");
        let generated = dir.path().join("preference.lua");
        let backups = dir.path().join("backups");
        fs::write(&config, "personal config\n").unwrap();
        if let Some(previous) = previous {
            fs::write(&generated, previous).unwrap();
        }
        Self {
            _dir: dir,
            config,
            generated,
            backups,
        }
    }
    fn update<'a>(
        &'a self,
        previous: Option<&'a str>,
        next: Option<&'a str>,
    ) -> GeneratedUpdate<'a> {
        GeneratedUpdate {
            config: &self.config,
            generated: &self.generated,
            backups: &self.backups,
            before: "personal config\n",
            after: "personal config\ninclude preference\n",
            generated_before: previous,
            generated_after: next,
        }
    }
}

#[test]
fn verification_failure_restores_both_files_including_first_apply() {
    for previous in [None, Some("old preference\n")] {
        let files = Files::new(previous);
        let mut desktop = Desktop::default();
        let error = config_file::apply_generated(
            &mut desktop,
            files.update(previous, Some("new preference\n")),
            |_| Err("verification failed".into()),
        )
        .unwrap_err();
        assert!(error.contains("Previous configuration restored"));
        assert_eq!(
            fs::read_to_string(&files.config).unwrap(),
            "personal config\n"
        );
        assert_eq!(
            fs::read_to_string(&files.generated).ok().as_deref(),
            previous
        );
        assert_eq!(
            desktop.calls, 4,
            "apply and recovery each check configuration errors"
        );
    }
}

#[test]
fn reset_removes_only_the_owned_generated_file_after_success() {
    let files = Files::new(Some("old preference\n"));
    let mut desktop = Desktop::default();
    config_file::apply_generated(
        &mut desktop,
        files.update(Some("old preference\n"), None),
        |_| {
            assert_eq!(
                fs::read_to_string(&files.generated).unwrap(),
                "old preference\n"
            );
            Ok(())
        },
    )
    .unwrap();
    assert!(!files.generated.exists());
}

#[test]
fn edits_during_a_failed_reload_are_never_overwritten() {
    let files = Files::new(Some("old preference\n"));
    let mut desktop = Desktop {
        edit_on_reload: Some(files.config.clone()),
        ..Desktop::default()
    };
    let error = config_file::apply_generated(
        &mut desktop,
        files.update(Some("old preference\n"), Some("new preference\n")),
        |_| Ok(()),
    )
    .unwrap_err();
    assert!(error.contains("changed externally"));
    assert_eq!(
        fs::read_to_string(&files.config).unwrap(),
        "personal edit during reload\n"
    );
    assert_eq!(
        desktop.calls, 1,
        "do not reload a rollback over external edits"
    );
}

#[test]
fn a_generated_file_changed_after_preparation_is_preserved() {
    let files = Files::new(Some("external edit\n"));
    let mut desktop = Desktop::default();
    assert!(
        config_file::apply_generated(
            &mut desktop,
            files.update(Some("expected old\n"), Some("new\n")),
            |_| Ok(())
        )
        .unwrap_err()
        .contains("changed externally")
    );
    assert_eq!(
        fs::read_to_string(&files.generated).unwrap(),
        "external edit\n"
    );
    assert_eq!(
        fs::read_to_string(&files.config).unwrap(),
        "personal config\n"
    );
    assert_eq!(desktop.calls, 0);
}
