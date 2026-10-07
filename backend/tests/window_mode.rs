use familiar_desktop::{
    Result,
    common::Hypr,
    window_mode::{self, Paths},
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
    windows: Vec<serde_json::Value>,
    fail_window: bool,
    window_lua: Option<String>,
}
impl Hypr for FakeHypr {
    fn command(&mut self, args: &[&str]) -> Result<String> {
        self.calls
            .push(args.iter().map(|s| s.to_string()).collect());
        if args == ["-j", "clients"] {
            return Ok(serde_json::to_string(&self.windows).unwrap());
        }
        if args.first() == Some(&"eval")
            && args.get(1).is_some_and(|s| s.contains("local w="))
            && self.fail_window
        {
            return Err("Window closed".into());
        }
        if args.first() == Some(&"eval")
            && args.get(1).is_some_and(|s| s.contains("local w="))
            && let Some(harness) = &self.window_lua
        {
            let output = std::process::Command::new("lua")
                .args(["-e", &format!("{harness}\n{}\nassert(dispatched)", args[1])])
                .output()
                .expect("Lua is required for window-mode dispatcher tests");
            return if output.status.success() {
                Ok("ok".into())
            } else {
                Err(String::from_utf8_lossy(&output.stderr).into_owned())
            };
        }
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
fn status_and_invalid_requests_never_mutate_or_reload() {
    let (_dir, p) = fixture();
    let before = fs::read(&p.config).unwrap();
    let mut h = FakeHypr::default();
    assert_eq!(
        window_mode::change("status", &p, &mut h).unwrap()["mode"],
        "reset"
    );
    assert!(!p.state.exists());
    assert!(window_mode::change("bad", &p, &mut h).is_err());
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
    for mode in ["floating", "tiling", "floating", "tiling"] {
        let result = window_mode::change(mode, &p, &mut h).unwrap();
        assert_eq!(result["mode"], mode);
        let current = fs::read_to_string(&p.config).unwrap();
        assert_eq!(
            window_mode::split_current(&current, &p).unwrap(),
            (before.clone(), mode.into())
        );
        assert_eq!(
            fs::metadata(&p.config).unwrap().permissions().mode() & 0o777,
            0o640
        );
        assert_eq!(
            window_mode::change("status", &p, &mut h).unwrap()["mode"],
            mode
        );
    }
    window_mode::change("reset", &p, &mut h).unwrap();
    window_mode::change("reset", &p, &mut h).unwrap();
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
    window_mode::change("floating", &p, &mut h).unwrap();
    let mut text = fs::read_to_string(&p.config).unwrap();
    text.push_str("\n-- later personal change\n");
    fs::write(&p.config, text).unwrap();
    window_mode::change("reset", &p, &mut h).unwrap();
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
        window_mode::change("floating", &p, &mut h).unwrap();
        let before = fs::read(&p.config).unwrap();
        h.fail_reload = !config_error;
        h.config_error = config_error;
        assert!(
            window_mode::change("floating", &p, &mut h)
                .unwrap_err()
                .contains("Previous configuration restored")
        );
        assert_eq!(fs::read(&p.config).unwrap(), before);
        assert_eq!(
            window_mode::change("status", &p, &mut h).unwrap()["mode"],
            "floating"
        );
    }
}

#[test]
fn damaged_foreign_or_edited_blocks_are_not_overwritten() {
    let (_dir, p) = fixture();
    let block = window_mode::hook("floating", &p.manifest).unwrap();
    let variants = [
        block.replace("-- END FAMILIAR WINDOW MODE\n", ""),
        block.repeat(2),
        block.replace("float = true", "float = false"),
        window_mode::hook("floating", &p.manifest.with_file_name("other.json")).unwrap(),
    ];
    for content in variants {
        fs::write(&p.config, &content).unwrap();
        let mut h = FakeHypr::default();
        assert!(window_mode::change("reset", &p, &mut h).is_err());
        assert_eq!(fs::read_to_string(&p.config).unwrap(), content);
        assert!(h.calls.is_empty());
    }
}

#[test]
fn missing_symlink_and_nonregular_config_fail_closed() {
    let (_dir, p) = fixture();
    fs::remove_file(&p.config).unwrap();
    let mut h = FakeHypr::default();
    assert!(window_mode::change("floating", &p, &mut h).is_err());
    symlink("missing-target", &p.config).unwrap();
    assert!(window_mode::change("floating", &p, &mut h).is_err());
    assert!(
        fs::symlink_metadata(&p.config)
            .unwrap()
            .file_type()
            .is_symlink()
    );
    fs::remove_file(&p.config).unwrap();
    fs::create_dir(&p.config).unwrap();
    assert!(window_mode::change("floating", &p, &mut h).is_err());
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
    assert!(window_mode::change("floating", &p, &mut h).is_err());
    assert_eq!(fs::read(&p.config).unwrap(), before);
}

#[test]
fn owned_generated_file_is_guarded_and_edited_content_is_preserved() {
    let (_dir, p) = fixture();
    let mut h = FakeHypr::default();
    window_mode::change("floating", &p, &mut h).unwrap();
    let generated = fs::read_to_string(&p.generated).unwrap();
    assert!(generated.contains("hl.window_rule"));
    let edited = format!("{generated}\n-- personal edit\n");
    fs::write(&p.generated, &edited).unwrap();
    assert!(window_mode::change("reset", &p, &mut h).is_err());
    assert_eq!(fs::read_to_string(&p.generated).unwrap(), edited);
}

#[test]
fn generated_lua_adds_only_opt_in_float_rule_and_stops_after_removal() {
    let (dir, p) = fixture();
    let hook = dir.path().join("hook.lua");
    fs::write(&hook, window_mode::hook("floating", &p.manifest).unwrap()).unwrap();
    let script = format!(
        r#"
local calls = 0
hl = {{ window_rule = function(rule)
  assert(rule.name == 'familiar-new-windows-floating')
  assert(rule.match.class == '.*' and rule.float == true)
  calls = calls + 1
end }}
dofile({})
assert(calls == 1)
io.open = function() return nil end
dofile({})
assert(calls == 1)
"#,
        familiar_desktop::common::lua(&hook.to_string_lossy()),
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

#[test]
fn switch_changes_existing_windows_and_skips_protected_windows() {
    let (_dir, p) = fixture();
    let normal = serde_json::json!({"address":"0xABC","pid":42,"initialClass":"kitty","mapped":true,"workspace":{"id":2},"fullscreen":0});
    let mut h = FakeHypr {
        windows: vec![normal.clone()],
        ..Default::default()
    };
    for field in ["hidden", "pinned"] {
        let mut protected = normal.clone();
        protected[field] = serde_json::json!(true);
        h.windows.push(protected);
    }
    let mut special = normal.clone();
    special["workspace"]["id"] = serde_json::json!(-99);
    h.windows.push(special);
    let mut fullscreen = normal.clone();
    fullscreen["fullscreen"] = serde_json::json!(2);
    h.windows.push(fullscreen);
    let mut grouped = normal.clone();
    grouped["grouped"] = serde_json::json!(["0xABC", "0xDEF"]);
    h.windows.push(grouped);
    for mode in ["floating", "tiling"] {
        let r = window_mode::switch(mode, &p, &mut h).unwrap();
        assert_eq!(r["changed"], 1);
        assert_eq!(r["skipped"], 5);
        assert_eq!(r["failed"], 0);
    }
    assert!(
        h.calls
            .iter()
            .any(|c| c.iter().any(|s| s.contains("w.pid==42")
                && s.contains("action='unset'")
                && s.contains("w.initial_class")))
    );
    h.fail_window = true;
    let r = window_mode::switch("tiling", &p, &mut h).unwrap();
    assert_eq!(r["failed"], 1);
    assert!(r["message"].as_str().unwrap().contains("Retry"));
}

#[test]
fn switch_executes_dispatchers_and_reports_live_failures() {
    for mode in ["floating", "tiling"] {
        for (mutation, dispatch_ok, failed) in [
            ("", true, 0),
            ("", false, 1),
            ("w.pid = 99", true, 1),
            ("w.initial_class = 'other'", true, 1),
            ("w.mapped = false", true, 1),
            ("w.hidden = true", true, 1),
            ("w.pinned = true", true, 1),
            ("w.fullscreen = 2", true, 1),
            ("w.group = {}", true, 1),
            ("w.workspace.id = -99", true, 1),
            ("w = nil", true, 1),
        ] {
            let (_dir, p) = fixture();
            let action = if mode == "floating" { "set" } else { "unset" };
            let harness = format!(
                r#"
local w = {{pid=42, initial_class='kitty', mapped=true, fullscreen=0, workspace={{id=2}}}}
{mutation}
local dispatcher = setmetatable({{}}, {{__call=function()
  error('dispatcher objects cannot be called directly; use hl.dispatch(dispatcher)')
end}})
hl = {{
  get_window = function(selector)
    assert(selector == 'address:0xABC')
    return w
  end,
  dsp = {{window = {{float = function(options)
    assert(options.window == 'address:0xABC' and options.action == '{action}')
    return dispatcher
  end}}}},
  dispatch = function(value)
    assert(value == dispatcher)
    dispatched = true
    return {{ok={dispatch_ok}}}
  end
}}
"#
            );
            let mut h = FakeHypr {
                windows: vec![
                    serde_json::json!({"address":"0xABC","pid":42,"initialClass":"kitty","mapped":true,"workspace":{"id":2},"fullscreen":0}),
                ],
                window_lua: Some(harness),
                ..Default::default()
            };
            let result = window_mode::switch(mode, &p, &mut h).unwrap();
            assert_eq!(
                result["failed"], failed,
                "{mode}: {mutation}, ok={dispatch_ok}"
            );
            assert_eq!(result["changed"], 1 - failed);
            assert_eq!(result["skipped"], 0);
        }
    }
}
