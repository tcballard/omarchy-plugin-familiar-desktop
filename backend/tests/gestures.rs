use familiar_desktop::{
    Result,
    common::Hypr,
    gestures::{self, Paths},
};
use std::{
    fs,
    os::unix::fs::{PermissionsExt, symlink},
};

#[derive(Default)]
struct FakeHypr {
    calls: Vec<Vec<String>>,
    fail_reload: bool,
    config_error: bool,
    fail_probe: bool,
    config_errors_json: Option<String>,
}
impl Hypr for FakeHypr {
    fn command(&mut self, args: &[&str]) -> Result<String> {
        self.calls
            .push(args.iter().map(|s| s.to_string()).collect());
        if args == ["reload"] && self.fail_reload {
            self.fail_reload = false;
            return Err("fixture reload failure".into());
        }
        if args.first() == Some(&"eval") && self.fail_probe {
            return Err("unsupported Lua API".into());
        }
        if args == ["-j", "configerrors"] {
            if self.config_error {
                self.config_error = false;
                return Ok("[\"fixture parse error\"]".into());
            }
            return Ok(self
                .config_errors_json
                .clone()
                .unwrap_or_else(|| "[\"\"]".into()));
        }
        Ok("ok".into())
    }
}
fn fixture() -> (tempfile::TempDir, Paths) {
    let dir = tempfile::tempdir().unwrap();
    let paths = Paths {
        config: dir.path().join("hyprland.lua"),
        manifest: dir.path().join("plugin 'quoted'/manifest.json"),
        state: dir.path().join("state"),
        generated: dir.path().join("familiar-trackpad/gestures.lua"),
    };
    fs::write(&paths.config, "-- personal config\nrequire('hypr.input')\n").unwrap();
    fs::set_permissions(&paths.config, fs::Permissions::from_mode(0o640)).unwrap();
    fs::create_dir_all(paths.manifest.parent().unwrap()).unwrap();
    fs::write(&paths.manifest, "{}").unwrap();
    (dir, paths)
}

#[test]
fn status_and_invalid_requests_never_mutate_or_reload() {
    let (_dir, p) = fixture();
    let before = fs::read(&p.config).unwrap();
    let mut h = FakeHypr::default();
    assert_eq!(
        gestures::change("status", &p, &mut h).unwrap()["mode"],
        "reset"
    );
    assert!(!p.state.exists());
    assert!(gestures::change("bad", &p, &mut h).is_err());
    assert_eq!(fs::read(&p.config).unwrap(), before);
    assert!(h.calls.is_empty());
}

#[test]
fn choices_persist_preserve_personal_content_and_reset_exactly() {
    let (_dir, p) = fixture();
    let before = fs::read_to_string(&p.config).unwrap();
    let input = p.config.with_file_name("input.lua");
    fs::write(&input, "-- custom UK keyboard and AltGr").unwrap();
    let mut h = FakeHypr::default();
    for mode in ["all", "workspace", "desktop", "all"] {
        let result = gestures::change(mode, &p, &mut h).unwrap();
        assert_eq!(result["mode"], mode);
        let current = fs::read_to_string(&p.config).unwrap();
        assert_eq!(
            gestures::split_current(&current, &p).unwrap(),
            (before.clone(), mode.into())
        );
        assert_eq!(
            fs::metadata(&p.config).unwrap().permissions().mode() & 0o777,
            0o640
        );
        assert_eq!(
            gestures::change("status", &p, &mut h).unwrap()["mode"],
            mode
        );
    }
    gestures::change("reset", &p, &mut h).unwrap();
    gestures::change("reset", &p, &mut h).unwrap();
    assert_eq!(fs::read_to_string(&p.config).unwrap(), before);
    assert_eq!(
        fs::read_to_string(input).unwrap(),
        "-- custom UK keyboard and AltGr"
    );
}

#[test]
fn reset_preserves_later_user_edits_and_handles_no_trailing_newline() {
    let (_dir, p) = fixture();
    fs::write(&p.config, "-- no trailing newline").unwrap();
    let mut h = FakeHypr::default();
    gestures::change("all", &p, &mut h).unwrap();
    let mut text = fs::read_to_string(&p.config).unwrap();
    text.push_str("\n-- later personal change\n");
    fs::write(&p.config, text).unwrap();
    gestures::change("reset", &p, &mut h).unwrap();
    assert_eq!(
        fs::read_to_string(&p.config).unwrap(),
        "-- no trailing newline\n-- later personal change\n"
    );
}

#[test]
fn reload_or_configuration_failure_restores_previous_choice() {
    for config_error in [false, true] {
        let (_dir, p) = fixture();
        let mut h = FakeHypr::default();
        gestures::change("all", &p, &mut h).unwrap();
        let before = fs::read(&p.config).unwrap();
        h.fail_reload = !config_error;
        h.config_error = config_error;
        assert!(
            gestures::change("all", &p, &mut h)
                .unwrap_err()
                .contains("Previous configuration restored")
        );
        assert_eq!(fs::read(&p.config).unwrap(), before);
        assert_eq!(
            gestures::change("status", &p, &mut h).unwrap()["mode"],
            "all"
        );
    }
}

#[test]
fn damaged_foreign_or_edited_blocks_are_not_overwritten() {
    let (_dir, p) = fixture();
    let block = gestures::hook("all", &p.manifest).unwrap();
    let variants = [
        block.replace("-- END FAMILIAR TRACKPAD MODE\n", ""),
        block.repeat(2),
        block.replace("fingers = 4", "fingers = 5"),
        gestures::hook("all", &p.manifest.with_file_name("other.json")).unwrap(),
    ];
    for content in variants {
        fs::write(&p.config, &content).unwrap();
        let mut h = FakeHypr::default();
        assert!(gestures::change("reset", &p, &mut h).is_err());
        assert_eq!(fs::read_to_string(&p.config).unwrap(), content);
        assert!(h.calls.is_empty());
    }
}

#[test]
fn missing_symlink_and_nonregular_config_fail_closed() {
    let (_dir, p) = fixture();
    fs::remove_file(&p.config).unwrap();
    let mut h = FakeHypr::default();
    assert!(gestures::change("all", &p, &mut h).is_err());
    symlink("missing-target", &p.config).unwrap();
    assert!(gestures::change("all", &p, &mut h).is_err());
    assert!(
        fs::symlink_metadata(&p.config)
            .unwrap()
            .file_type()
            .is_symlink()
    );
    fs::remove_file(&p.config).unwrap();
    fs::create_dir(&p.config).unwrap();
    assert!(gestures::change("all", &p, &mut h).is_err());
    assert!(h.calls.is_empty());
}

#[test]
fn incompatible_compositor_keeps_config_unchanged() {
    let (_dir, p) = fixture();
    let before = fs::read(&p.config).unwrap();
    let mut h = FakeHypr {
        fail_probe: true,
        ..Default::default()
    };
    assert!(gestures::change("all", &p, &mut h).is_err());
    assert_eq!(fs::read(&p.config).unwrap(), before);
}

#[test]
fn owned_generated_file_is_guarded_and_edited_content_is_preserved() {
    let (_dir, p) = fixture();
    let mut h = FakeHypr::default();
    gestures::change("all", &p, &mut h).unwrap();
    let generated = fs::read_to_string(&p.generated).unwrap();
    assert!(generated.contains("hl.gesture"));
    let legacy = generated
        .replace("action = function() hl.dispatch(", "action = ")
        .replace(")) end })", ") })");
    assert_eq!(gestures::split(&legacy, &p.manifest).unwrap().1, "all");
    fs::write(&p.generated, legacy).unwrap();
    gestures::change("all", &p, &mut h).unwrap();
    assert_eq!(fs::read_to_string(&p.generated).unwrap(), generated);
    let edited = format!("{generated}\n-- personal edit\n");
    fs::write(&p.generated, &edited).unwrap();
    assert!(gestures::change("reset", &p, &mut h).is_err());
    assert_eq!(fs::read_to_string(&p.generated).unwrap(), edited);
}

#[test]
fn generated_lua_registers_selected_groups_without_executing_actions() {
    let (dir, p) = fixture();
    for mode in ["all", "workspace", "desktop"] {
        let hook = dir.path().join("hook.lua");
        fs::write(&hook, gestures::hook(mode, &p.manifest).unwrap()).unwrap();
        let script = format!(
            r#"
local calls, commands = {{}}, {{}}
hl = {{ dsp = {{ exec_cmd = function(command)
  return {{command=command}}
end }}, dispatch = function(object)
  assert(type(object)=='table'); table.insert(commands, object.command)
end, gesture = function(g)
  assert(type(g.action)=='string' or type(g.action)=='function')
  table.insert(calls, g)
end }}
dofile({})
assert(#commands == 0)
local mode = {}
assert(#calls == (mode == 'all' and 3 or mode == 'workspace' and 1 or 2))
if mode ~= 'desktop' then
  assert(calls[1].fingers == 3 and calls[1].direction == 'horizontal' and calls[1].action == 'workspace')
end
if mode ~= 'workspace' then
  calls[#calls-1].action()
  calls[#calls].action()
  assert(#commands == 2)
  assert(commands[1]:find('desktop show', 1, true))
  assert(commands[2]:find('desktop restore', 1, true))
  assert(calls[#calls].fingers == 4 and calls[#calls].direction == 'up')
end
local count = #calls
io.open = function() return nil end
dofile({})
assert(#calls == count)
"#,
            familiar_desktop::common::lua(&hook.to_string_lossy()),
            familiar_desktop::common::lua(mode),
            familiar_desktop::common::lua(&hook.to_string_lossy())
        );
        let harness = dir.path().join("test.lua");
        fs::write(&harness, script).unwrap();
        assert!(
            std::process::Command::new("lua")
                .arg(harness)
                .status()
                .unwrap()
                .success()
        );
    }
}
