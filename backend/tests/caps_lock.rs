use familiar_desktop::{Result, caps_lock::{self, Paths}, common::Hypr};
use std::{fs, os::unix::fs::{PermissionsExt, symlink}, process::Command};

#[derive(Default)]
struct FakeHypr {
    calls: Vec<Vec<String>>,
    fail_reload: bool,
    config_error: bool,
    fail_probe: bool,
}
impl Hypr for FakeHypr {
    fn command(&mut self, args: &[&str]) -> Result<String> {
        self.calls.push(args.iter().map(|s| s.to_string()).collect());
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
            return Ok("[]".into());
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
    assert_eq!(caps_lock::change("status", &p, &mut h).unwrap()["mode"], "reset");
    assert!(!p.state.exists());
    assert!(caps_lock::change("bad", &p, &mut h).is_err());
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
    for mode in ["normal", "normal", "compose", "compose"] {
        let result = caps_lock::change(mode, &p, &mut h).unwrap();
        assert_eq!(result["mode"], mode);
        let current = fs::read_to_string(&p.config).unwrap();
        assert_eq!(caps_lock::split(&current, &p.manifest).unwrap(), (before.clone(), mode.into()));
        assert_eq!(fs::metadata(&p.config).unwrap().permissions().mode() & 0o777, 0o640);
        assert_eq!(caps_lock::change("status", &p, &mut h).unwrap()["mode"], mode);
    }
    caps_lock::change("reset", &p, &mut h).unwrap();
    caps_lock::change("reset", &p, &mut h).unwrap();
    assert_eq!(fs::read_to_string(&p.config).unwrap(), before);
    assert_eq!(fs::read_to_string(input).unwrap(), "-- custom UK keyboard and AltGr");
}

#[test]
fn reset_preserves_later_user_edits_and_handles_no_trailing_newline() {
    let (_dir, p) = fixture();
    fs::write(&p.config, "-- no trailing newline").unwrap();
    let mut h = FakeHypr::default();
    caps_lock::change("normal", &p, &mut h).unwrap();
    let mut text = fs::read_to_string(&p.config).unwrap();
    text.push_str("\n-- later personal change\n");
    fs::write(&p.config, text).unwrap();
    caps_lock::change("reset", &p, &mut h).unwrap();
    assert_eq!(fs::read_to_string(&p.config).unwrap(), "-- no trailing newline\n-- later personal change\n");
}

#[test]
fn reload_or_configuration_failure_restores_previous_choice() {
    for config_error in [false, true] {
        let (_dir, p) = fixture();
        let mut h = FakeHypr::default();
        caps_lock::change("normal", &p, &mut h).unwrap();
        let before = fs::read(&p.config).unwrap();
        h.fail_reload = !config_error;
        h.config_error = config_error;
        assert!(caps_lock::change("compose", &p, &mut h).unwrap_err().contains("Previous configuration restored"));
        assert_eq!(fs::read(&p.config).unwrap(), before);
        assert_eq!(caps_lock::change("status", &p, &mut h).unwrap()["mode"], "normal");
    }
}

#[test]
fn damaged_foreign_or_edited_blocks_are_not_overwritten() {
    let (_dir, p) = fixture();
    let block = caps_lock::hook("normal", &p.manifest).unwrap();
    let variants = [
        block.replace("-- END FAMILIAR CAPS LOCK\n", ""),
        block.repeat(2),
        block.replace("caps:capslock", "caps:escape"),
        caps_lock::hook("normal", &p.manifest.with_file_name("other.json")).unwrap(),
    ];
    for content in variants {
        fs::write(&p.config, &content).unwrap();
        let mut h = FakeHypr::default();
        assert!(caps_lock::change("reset", &p, &mut h).is_err());
        assert_eq!(fs::read_to_string(&p.config).unwrap(), content);
        assert!(h.calls.is_empty());
    }
}

#[test]
fn missing_symlink_and_nonregular_config_fail_closed() {
    let (_dir, p) = fixture();
    fs::remove_file(&p.config).unwrap();
    let mut h = FakeHypr::default();
    assert!(caps_lock::change("normal", &p, &mut h).is_err());
    symlink("missing-target", &p.config).unwrap();
    assert!(caps_lock::change("normal", &p, &mut h).is_err());
    assert!(fs::symlink_metadata(&p.config).unwrap().file_type().is_symlink());
    fs::remove_file(&p.config).unwrap();
    fs::create_dir(&p.config).unwrap();
    assert!(caps_lock::change("normal", &p, &mut h).is_err());
    assert!(h.calls.is_empty());
}

#[test]
fn incompatible_compositor_keeps_config_unchanged() {
    let (_dir, p) = fixture();
    let before = fs::read(&p.config).unwrap();
    let mut h = FakeHypr { fail_probe: true, ..Default::default() };
    assert!(caps_lock::change("normal", &p, &mut h).is_err());
    assert_eq!(fs::read(&p.config).unwrap(), before);
}

#[test]
fn generated_lua_preserves_altgr_other_compose_and_layout_options() {
    let (dir, p) = fixture();
    // Execute the actual generated hook, not a second implementation of its filter.
    for (mode, wanted) in [("normal", "caps:capslock"), ("compose", "compose:caps")] {
        let hook = dir.path().join("hook.lua");
        fs::write(&hook, caps_lock::hook(mode, &p.manifest).unwrap()).unwrap();
        let harness = dir.path().join("check.lua");
        let script = format!(r#"
local hook = {}
for _, fixture in ipairs({{
  {{"compose:caps,shift:both_capslock_cancel,grp:alts_toggle,lv3:ralt_switch", "grp:alts_toggle,lv3:ralt_switch,{wanted}"}},
  {{"ctrl:nocaps,compose:rctrl,grp:caps_toggle", "compose:rctrl,{wanted}"}},
  {{"caps:escape, grp:alt_shift_toggle ", "grp:alt_shift_toggle,{wanted}"}},
  {{"", "{wanted}"}}
}}) do
  local actual = fixture[1]
  hl = {{ get_config = function(key) assert(key == "input.kb_options"); return actual end,
    config = function(value) actual = value.input.kb_options end }}
  dofile(hook)
  assert(actual == fixture[2], actual)
  dofile(hook)
  assert(actual == fixture[2], "repeated reload changed options")
end
-- A removed plugin must not leave an active keyboard override.
io.open = function() return nil end
hl = {{ get_config = function() error("removed plugin read config") end,
  config = function() error("removed plugin changed config") end }}
dofile(hook)
"#, familiar_desktop::common::lua(&hook.to_string_lossy()));
        fs::write(&harness, script).unwrap();
        let output = Command::new("lua").arg(&harness).output().expect("Install Lua for development tests");
        assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    }
}
