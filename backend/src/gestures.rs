//! Explicit, reversible trackpad preference. Never rewrite input.lua or core files.
use crate::config_file::{self, GeneratedUpdate, read as text};
use crate::{
    Result,
    common::{self, Hypr, checked},
};
use serde_json::{Value, json};
use std::{
    fs,
    path::{Path, PathBuf},
};

const BEGIN: &str = "\n-- BEGIN FAMILIAR TRACKPAD MODE\n";
const END: &str = "-- END FAMILIAR TRACKPAD MODE\n";

pub struct Paths {
    pub config: PathBuf,
    pub manifest: PathBuf,
    pub state: PathBuf,
    pub generated: PathBuf,
}

impl Paths {
    pub fn system() -> Result<Self> {
        let binary = std::env::current_exe().map_err(|e| e.to_string())?;
        let source = binary
            .parent()
            .and_then(Path::parent)
            .ok_or("Install the helper in the plugin bin directory")?;
        let state = std::env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or(common::home()?.join(".local/state"));
        Ok(Self {
            config: common::config_home()?.join("hypr/hyprland.lua"),
            manifest: source.join("manifest.json"),
            state: state.join("omarchy/familiar-gestures"),
            generated: common::config_home()?.join("omarchy/familiar-trackpad/gestures.lua"),
        })
    }
}

pub fn hook(mode: &str, manifest: &Path) -> Result<String> {
    hook_version(mode, manifest, false)
}

fn hook_version(mode: &str, manifest: &Path, legacy: bool) -> Result<String> {
    if !["all", "workspace", "desktop"].contains(&mode) {
        return Err("Choose all, workspace, desktop or reset".into());
    }
    let helper = manifest
        .parent()
        .ok_or("Missing plugin directory")?
        .join("bin/familiar-desktop");
    let command = common::shell_quote(&helper.to_string_lossy());
    let mut body = String::new();
    if mode == "all" || mode == "workspace" {
        body.push_str(
            "    hl.gesture({ fingers = 3, direction = 'horizontal', action = 'workspace' })\n",
        );
    }
    if mode == "all" || mode == "desktop" {
        for (direction, action) in [("down", "show"), ("up", "restore")] {
            let dispatcher = format!(
                "hl.dsp.exec_cmd({})",
                common::lua(&format!("{command} desktop {action}"))
            );
            let callback = if legacy {
                dispatcher
            } else {
                format!("function() hl.dispatch({dispatcher}) end")
            };
            body.push_str(&format!(
                "    hl.gesture({{ fingers = 4, direction = '{direction}', action = {callback} }})\n"
            ));
        }
    }
    Ok(format!(
        "{BEGIN}-- mode: {mode}\ndo\n  local plugin = io.open({}, 'r')\n  if plugin then\n    plugin:close()\n{body}  end\nend\n{END}",
        common::lua(&manifest.to_string_lossy())
    ))
}

// Only this stable, guarded include lives in the user's main configuration.
pub fn include_hook(paths: &Paths) -> String {
    format!(
        "\n-- BEGIN FAMILIAR TRACKPAD PREFERENCE\ndo\n  local plugin = io.open({}, 'r')\n  if plugin then\n    plugin:close()\n    local config = io.open({}, 'r')\n    if config then config:close(); dofile({}) end\n  end\nend\n-- END FAMILIAR TRACKPAD PREFERENCE\n",
        common::lua(&paths.manifest.to_string_lossy()),
        common::lua(&paths.generated.to_string_lossy()),
        common::lua(&paths.generated.to_string_lossy())
    )
}

fn generated_content(paths: &Paths) -> Result<Option<String>> {
    match fs::symlink_metadata(&paths.generated) {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.to_string()),
        Ok(_) => {
            let value = text(&paths.generated)?;
            if !["all", "workspace", "desktop"].iter().any(|mode| {
                [false, true].into_iter().any(|legacy| {
                    hook_version(mode, &paths.manifest, legacy)
                        .is_ok_and(|expected| value == expected)
                })
            }) {
                return Err(
                    "Familiar's separate trackpad config was edited; no file changed".into(),
                );
            }
            Ok(Some(value))
        }
    }
}

pub fn split_current(value: &str, paths: &Paths) -> Result<(String, String)> {
    if value.contains("-- BEGIN FAMILIAR TRACKPAD PREFERENCE")
        || value.contains("-- END FAMILIAR TRACKPAD PREFERENCE")
    {
        let clean = crate::config_file::strip_exact(
            value,
            "-- BEGIN FAMILIAR TRACKPAD PREFERENCE",
            "-- END FAMILIAR TRACKPAD PREFERENCE",
            &include_hook(paths),
        )?;
        let (_, legacy) = split(&clean, &paths.manifest)?;
        if legacy != "reset" {
            return Err("Duplicate legacy and separate trackpad hooks; no file changed".into());
        }
        let mode = match generated_content(paths)? {
            Some(content) => split(&content, &paths.manifest)?.1,
            None => "reset".into(),
        };
        return Ok((clean, mode));
    }
    split(value, &paths.manifest)
}

pub fn split(text: &str, manifest: &Path) -> Result<(String, String)> {
    let starts = text.matches("-- BEGIN FAMILIAR TRACKPAD MODE").count();
    let ends = text.matches("-- END FAMILIAR TRACKPAD MODE").count();
    if starts == 0 && ends == 0 {
        return Ok((text.into(), "reset".into()));
    }
    if starts == 1 && ends == 1 {
        for mode in ["all", "workspace", "desktop"] {
            for legacy in [false, true] {
                let block = hook_version(mode, manifest, legacy)?;
                if let Some(start) = text.find(&block) {
                    return Ok((
                        format!("{}{}", &text[..start], &text[start + block.len()..]),
                        mode.into(),
                    ));
                }
            }
        }
    }

    Err("Familiar Trackpad block was edited, damaged or belongs to another installation; no file changed".into())
}

pub fn change(mode: &str, paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    if !["all", "workspace", "desktop", "reset", "status"].contains(&mode) {
        return Err("Usage: familiar-desktop gestures <all|workspace|desktop|reset|status>".into());
    }
    let _lock = if mode == "status" {
        None
    } else {
        Some(common::lock(&paths.state.join("config.lock"))?)
    };
    let before = text(&paths.config)?;
    let (clean, previous) = split_current(&before, paths)?;
    if mode == "status" {
        return Ok(
            json!({"state":"ok","mode":previous,"message":"Opt-in gestures. Existing gesture conflicts cause rollback; choose a separate group if needed."}),
        );
    }
    let after = if mode == "reset" {
        clean
    } else {
        if !paths.manifest.is_file() {
            return Err("Familiar manifest is missing; no file changed".into());
        }
        // Refuse unsupported compositor APIs before touching the user's config.
        checked(
            hypr,
            &[
                "eval",
                "assert(hl and hl.gesture and hl.dispatch and hl.dsp and hl.dsp.exec_cmd, 'Familiar Trackpad requires Hyprland Lua gesture support')",
            ],
        )?;
        format!("{}{}", clean, include_hook(paths))
    };
    let generated_before = generated_content(paths)?;
    let generated_after = if mode == "reset" {
        None
    } else {
        Some(hook(mode, &paths.manifest)?)
    };
    let backup = config_file::apply_generated(
        hypr,
        GeneratedUpdate {
            config: &paths.config,
            generated: &paths.generated,
            backups: &paths.state,
            before: &before,
            after: &after,
            generated_before: generated_before.as_deref(),
            generated_after: generated_after.as_deref(),
        },
        |_| Ok(()),
    )?;
    Ok(
        json!({"state":"ok","mode":mode,"backup":backup,"message":if mode == "reset" { "Familiar gesture preferences removed; your configuration is restored." } else { "Trackpad gestures enabled. Three fingers switch workspaces; four down shows desktop and four up restores, according to the selected group." }}),
    )
}

pub fn execute(args: &[String]) -> Result<Value> {
    if args.len() != 1 {
        return Err("Usage: familiar-desktop gestures <all|workspace|desktop|reset|status>".into());
    }
    change(&args[0], &Paths::system()?, &mut common::SystemHypr)
}
