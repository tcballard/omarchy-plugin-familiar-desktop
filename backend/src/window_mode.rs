//! Explicit, reversible window preference. Never rewrite input.lua or core files.
use crate::{
    Result,
    common::{self, Hypr, checked},
};
use serde_json::{Value, json};
use std::{
    fs,
    path::{Path, PathBuf},
};

const BEGIN: &str = "\n-- BEGIN FAMILIAR WINDOW MODE\n";
const END: &str = "-- END FAMILIAR WINDOW MODE\n";

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
            state: state.join("omarchy/familiar-window-mode"),
            generated: common::config_home()?.join("omarchy/familiar-windows/window-mode.lua"),
        })
    }
}

pub fn hook(mode: &str, manifest: &Path) -> Result<String> {
    if !["floating", "tiling"].contains(&mode) {
        return Err("Choose floating, tiling or reset".into());
    }
    if mode == "tiling" {
        return Ok(hook("floating", manifest)?
            .replace("-- mode: floating", "-- mode: tiling")
            .replace(
                "familiar-new-windows-floating",
                "familiar-new-windows-tiling",
            )
            .replace("float = true", "float = false"));
    }
    Ok(format!(
        "{BEGIN}-- mode: floating\ndo\n  local plugin = io.open({}, 'r')\n  if plugin then\n    plugin:close()\n    hl.window_rule({{ name = 'familiar-new-windows-floating', match = {{ class = '.*' }}, float = true }})\n  end\nend\n{END}",
        common::lua(&manifest.to_string_lossy())
    ))
}

// Only this stable, guarded include lives in the user's main configuration.
pub fn include_hook(paths: &Paths) -> String {
    format!(
        "\n-- BEGIN FAMILIAR WINDOW PREFERENCE\ndo\n  local plugin = io.open({}, 'r')\n  if plugin then\n    plugin:close()\n    local config = io.open({}, 'r')\n    if config then config:close(); dofile({}) end\n  end\nend\n-- END FAMILIAR WINDOW PREFERENCE\n",
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
            if value != hook("floating", &paths.manifest)?
                && value != hook("tiling", &paths.manifest)?
            {
                return Err("Familiar's separate window config was edited; no file changed".into());
            }
            Ok(Some(value))
        }
    }
}

pub fn split_current(value: &str, paths: &Paths) -> Result<(String, String)> {
    if value.contains("-- BEGIN FAMILIAR WINDOW PREFERENCE")
        || value.contains("-- END FAMILIAR WINDOW PREFERENCE")
    {
        let clean = crate::config_file::strip_exact(
            value,
            "-- BEGIN FAMILIAR WINDOW PREFERENCE",
            "-- END FAMILIAR WINDOW PREFERENCE",
            &include_hook(paths),
        )?;
        let (_, legacy) = split(&clean, &paths.manifest)?;
        if legacy != "reset" {
            return Err("Duplicate legacy and separate window hooks; no file changed".into());
        }
        let mode = match generated_content(paths)? {
            Some(content) => split(&content, &paths.manifest)?.1,
            None => "reset".into(),
        };
        return Ok((clean, mode));
    }
    split(value, &paths.manifest)
}

fn restore_generated(paths: &Paths, expected: &str, before: &Option<String>) -> Result<()> {
    if text(&paths.generated)? != expected {
        return Err(
            "Separate window config changed externally; preserve it and review the backup".into(),
        );
    }
    match before {
        Some(value) => common::atomic(&paths.generated, value.as_bytes()),
        None => fs::remove_file(&paths.generated).map_err(|e| e.to_string()),
    }
}

fn text(path: &Path) -> Result<String> {
    // Refuse symlink replacement (including broken links) and non-regular files.
    let metadata = fs::symlink_metadata(path).map_err(|e| e.to_string())?;
    if !metadata.file_type().is_file() {
        return Err(
            "Hyprland config must be a regular file, not a symlink; no file changed".into(),
        );
    }
    String::from_utf8(common::bounded_file(path, common::FILE_LIMIT)?).map_err(|e| e.to_string())
}

pub fn split(text: &str, manifest: &Path) -> Result<(String, String)> {
    let starts = text.matches("-- BEGIN FAMILIAR WINDOW MODE").count();
    let ends = text.matches("-- END FAMILIAR WINDOW MODE").count();
    if starts == 0 && ends == 0 {
        return Ok((text.into(), "reset".into()));
    }
    if starts == 1 && ends == 1 {
        for mode in ["floating", "tiling"] {
            let block = hook(mode, manifest)?;
            if let Some(start) = text.find(&block) {
                return Ok((
                    format!("{}{}", &text[..start], &text[start + block.len()..]),
                    mode.into(),
                ));
            }
        }
    }

    Err("Familiar Window mode block was edited, damaged or belongs to another installation; no file changed".into())
}

fn reload(hypr: &mut impl Hypr) -> Result<()> {
    checked(hypr, &["reload"])?;
    let errors: Vec<String> = serde_json::from_str(&hypr.command(&["-j", "configerrors"])?)
        .map_err(|_| "Could not verify Hyprland configuration errors")?;
    // Hyprland 0.56.2 / Hyprutils 0.14 serialises an empty error string as [""].
    // Ignore blank entries only; malformed responses and real diagnostics still fail.
    let errors: Vec<&str> = errors
        .iter()
        .map(|error| error.trim())
        .filter(|error| !error.is_empty())
        .collect();
    if !errors.is_empty() {
        return Err(format!(
            "Hyprland configuration error: {}",
            common::clipped(&errors.join("; "))
        ));
    }
    Ok(())
}

pub fn change(mode: &str, paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    if !["floating", "tiling", "reset", "status"].contains(&mode) {
        return Err("Usage: familiar-desktop window-mode <floating|tiling|reset|status>".into());
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
            json!({"state":"ok","mode":previous,"message":"Applies to newly opened windows; existing windows are unchanged."}),
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
                "assert(hl and hl.window_rule, 'Familiar Window mode requires Hyprland Lua configuration')",
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
    if let Some(content) = &generated_after {
        common::atomic(&paths.generated, content.as_bytes())?;
    }
    let backup = match crate::config_file::replace(&paths.config, &before, &after, &paths.state) {
        Ok(backup) => backup,
        Err(error) => {
            if let Some(content) = &generated_after {
                restore_generated(paths, content, &generated_before)?;
            }
            return Err(error);
        }
    };
    let applied = reload(hypr);
    if let Err(error) = applied {
        if text(&paths.config)? != after {
            return Err(format!(
                "{error}. Config changed externally; preserve your edits and recover from {backup:?}"
            ));
        }
        if let Some(content) = &generated_after {
            restore_generated(paths, content, &generated_before)?;
        }
        crate::config_file::replace(&paths.config, &after, &before, &paths.state)?;
        let recovery = reload(hypr);
        return Err(format!(
            "{error}. Previous configuration restored on disk. Recovery reload: {}",
            recovery.err().unwrap_or_else(|| "ok".into())
        ));
    }
    if mode == "reset"
        && let Some(content) = &generated_before
    {
        restore_generated(paths, content, &None)?;
    }
    Ok(
        json!({"state":"ok","mode":mode,"backup":backup,"message":if mode == "reset" { "New windows follow your Hyprland rules again. Existing windows are unchanged." } else if mode == "tiling" { "New windows use Hyprland tiling. Existing windows are unchanged." } else { "New windows will float without splitting the tiled layout. Existing windows are unchanged." }}),
    )
}

pub fn execute(args: &[String]) -> Result<Value> {
    if args.len() == 2 && args[0] == "switch" {
        return switch(&args[1], &Paths::system()?, &mut common::SystemHypr);
    }
    if args.len() != 1 {
        return Err("Usage: familiar-desktop window-mode <floating|tiling|reset|status>".into());
    }
    change(&args[0], &Paths::system()?, &mut common::SystemHypr)
}

// Idempotent mode switching across regular workspaces. Hidden, pinned, grouped
// and fullscreen windows stay untouched. Each Lua action rechecks live identity.
pub fn switch(mode: &str, paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    if !["floating", "tiling"].contains(&mode) {
        return Err("Choose floating or tiling".into());
    }
    let windows: Vec<Value> = serde_json::from_str(&hypr.command(&["-j", "clients"])?)
        .map_err(|_| "Cannot read existing windows; nothing changed")?;
    if windows.len() > 512 {
        return Err("Too many windows to switch safely; nothing changed".into());
    }
    let mut result = change(mode, paths, hypr)?;
    let mut changed = 0;
    let mut skipped = 0;
    let mut failed = 0;
    for w in windows {
        let addr = w["address"].as_str().unwrap_or("");
        let pid = w["pid"].as_u64().unwrap_or(0);
        if !crate::dock::valid_address(addr)
            || pid <= 1
            || w["mapped"] != true
            || w["hidden"] == true
            || w["pinned"] == true
            || w["workspace"]["id"].as_i64().unwrap_or(-1) <= 0
            || w["fullscreen"].as_u64().unwrap_or(0) != 0
            || w["grouped"].as_array().is_some_and(|g| !g.is_empty())
        {
            skipped += 1;
            continue;
        }
        let selector = common::lua(&format!("address:{addr}"));
        let class = common::lua(w["initialClass"].as_str().unwrap_or(""));
        let action = if mode == "floating" { "set" } else { "unset" };
        let script = format!(
            "local w=hl.get_window({selector}); assert(w and w.pid=={pid} and w.initial_class=={class} and w.mapped and not w.hidden and not w.pinned and w.fullscreen==0 and not w.group and w.workspace and w.workspace.id>0, 'Window changed; retry mode switch'); local r=hl.dispatch(hl.dsp.window.float({{window={selector},action='{action}'}})); assert(not r or r.ok~=false, 'Window mode action failed')"
        );
        if checked(hypr, &["eval", &script]).is_ok() {
            changed += 1;
        } else {
            failed += 1;
        }
    }
    result["changed"] = json!(changed);
    result["skipped"] = json!(skipped);
    result["failed"] = json!(failed);
    result["message"] = json!(format!(
        "{mode} mode: {changed} windows updated, {skipped} protected windows skipped, {failed} failed. New windows use this mode.{}",
        if failed > 0 {
            " Retry this mode to finish; already updated windows are retained."
        } else {
            ""
        }
    ));
    Ok(result)
}
