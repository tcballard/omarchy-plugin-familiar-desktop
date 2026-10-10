use familiar_desktop::{Result, common::Hypr, input_preferences, window_mode::Paths};
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
        generated: dir.path().join("familiar-windows/window-mode.lua"),
    };
    fs::write(&paths.config, "-- personal config\nrequire('hypr.input')\n").unwrap();
    fs::set_permissions(&paths.config, fs::Permissions::from_mode(0o640)).unwrap();
    fs::create_dir_all(paths.manifest.parent().unwrap()).unwrap();
    fs::write(&paths.manifest, "{}").unwrap();
    (dir, paths)
}

#[test]
fn preferences_preserve_personal_config_and_reset_exactly() {
    for kind in ["resize", "command"] {
        let (_dir, p) = fixture();
        let before = fs::read_to_string(&p.config).unwrap();
        let mut h = FakeHypr::default();
        assert_eq!(
            input_preferences::change(kind, "status", &p, &mut h).unwrap()["mode"],
            "reset"
        );
        assert!(h.calls.is_empty());
        input_preferences::change(kind, "enable", &p, &mut h).unwrap();
        input_preferences::change(kind, "enable", &p, &mut h).unwrap();
        assert_eq!(
            input_preferences::change(kind, "status", &p, &mut h).unwrap()["mode"],
            "enable"
        );
        if kind == "command" {
            let current = input_preferences::hook(kind, &p.manifest).unwrap();
            let legacy = current.replace(
                include_str!("../src/command_shortcuts.lua"),
                include_str!("../src/legacy/command_shortcuts.lua"),
            );
            fs::write(&p.generated, legacy).unwrap();
            input_preferences::change(kind, "enable", &p, &mut h).unwrap();
            assert_eq!(fs::read_to_string(&p.generated).unwrap(), current);
        }
        let mut content = fs::read_to_string(&p.config).unwrap();
        content.push_str("-- later personal edit\n");
        fs::write(&p.config, content).unwrap();
        input_preferences::change(kind, "reset", &p, &mut h).unwrap();
        assert_eq!(
            fs::read_to_string(&p.config).unwrap(),
            format!("{before}-- later personal edit\n")
        );
        assert!(!p.generated.exists());
        assert_eq!(
            fs::metadata(&p.config).unwrap().permissions().mode() & 0o777,
            0o640
        );
    }
}

#[test]
fn first_enable_failure_rolls_back_and_edits_are_never_overwritten() {
    for kind in ["resize", "command"] {
        for config_error in [false, true] {
            let (_dir, p) = fixture();
            let before = fs::read(&p.config).unwrap();
            let mut h = FakeHypr {
                fail_reload: !config_error,
                config_error,
                ..Default::default()
            };
            assert!(input_preferences::change(kind, "enable", &p, &mut h).is_err());
            assert_eq!(fs::read(&p.config).unwrap(), before);
            assert!(!p.generated.exists());
        }
        let (_dir, p) = fixture();
        let mut h = FakeHypr::default();
        input_preferences::change(kind, "enable", &p, &mut h).unwrap();
        fs::write(&p.generated, "-- owner edit").unwrap();
        let before = fs::read(&p.config).unwrap();
        assert!(input_preferences::change(kind, "reset", &p, &mut h).is_err());
        assert_eq!(fs::read(&p.config).unwrap(), before);
        assert_eq!(fs::read_to_string(&p.generated).unwrap(), "-- owner edit");
    }
}

#[test]
fn invalid_kind_and_symlink_refuse_without_reload() {
    let (_dir, p) = fixture();
    let mut h = FakeHypr::default();
    assert!(input_preferences::change("bad", "enable", &p, &mut h).is_err());
    fs::remove_file(&p.config).unwrap();
    symlink("missing", &p.config).unwrap();
    assert!(input_preferences::change("resize", "enable", &p, &mut h).is_err());
    assert!(h.calls.is_empty());
}

#[test]
fn command_shortcuts_target_active_window_and_do_not_interrupt_known_terminals() {
    let (dir, p) = fixture();
    let hook = dir.path().join("shortcuts.lua");
    fs::write(
        &hook,
        input_preferences::hook("command", &p.manifest).unwrap(),
    )
    .unwrap();
    let harness = dir.path().join("test.lua");
    let script = format!(
        r#"
local bindings, removed, sent, timers = {{}}, {{}}, {{}}, {{}}
local active = {{ initial_class='firefox', address='0xA' }}
hl = {{
  unbind=function(chord) removed[chord]=true end,
  bind=function(chord,action,opts) bindings[chord]=action; assert(opts.description:find('Familiar')) end,
  get_active_window=function() return active end,
  dsp={{send_key_state=function(args) return args end}},
  dispatch=function(object) assert(type(object)=='table'); table.insert(sent,object) end,
  timer=function(action,opts)
    assert(opts.timeout==50 and opts.type=='oneshot')
    table.insert(timers,action)
  end
}}
dofile({})
assert(#sent==0)
local function press(chord)
  bindings[chord]()
  assert(#timers==1 and sent[#sent].state=='down')
  table.remove(timers,1)()
  assert(sent[#sent].state=='up' and sent[#sent].window==sent[#sent-1].window)
end
press('SUPER + C')
assert(sent[1].mods=='CTRL' and sent[1].key=='C' and sent[1].window==active)
press('SUPER + SHIFT + Z')
assert(sent[3].mods=='CTRL SHIFT' and sent[3].key=='Z')
active.initial_class='kitty'
press('SUPER + C')
press('SUPER + V')
assert(sent[5].mods=='CTRL SHIFT' and sent[7].mods=='CTRL SHIFT')
assert(bindings['SUPER + Z']().pass_event==true)
assert(bindings['SUPER + X']().pass_event==true)
assert(#sent==8 and #timers==0)
active=nil
bindings['SUPER + C']()
assert(#sent==8)
assert(removed['SUPER + C'] and not removed['SUPER + Return'])
assert(not bindings['SUPER + Return'])
"#,
        familiar_desktop::common::lua(&hook.to_string_lossy())
    );
    fs::write(&harness, script).unwrap();
    assert!(
        std::process::Command::new("lua")
            .arg(harness)
            .status()
            .unwrap()
            .success()
    );
}
