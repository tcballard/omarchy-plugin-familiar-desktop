//! Explicit, reversible keyboard preference. Never rewrite input.lua or core files.
use crate::{
    Result,
    common::{self, Hypr, checked},
};
use serde_json::{Value, json};
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
};

const BEGIN: &str = "\n-- BEGIN FAMILIAR CAPS LOCK\n";
const END: &str = "-- END FAMILIAR CAPS LOCK\n";

pub struct Paths {
    pub config: PathBuf,
    pub manifest: PathBuf,
    pub state: PathBuf,
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
            state: state.join("omarchy/familiar-caps-lock"),
        })
    }
}

pub fn hook(mode: &str, manifest: &Path) -> Result<String> {
    let option = match mode {
        "normal" => "caps:capslock",
        "compose" => "compose:caps",
        _ => return Err("Choose normal, compose or reset".into()),
    };
    Ok(format!(
        "{BEGIN}-- mode: {mode}\ndo\n  local plugin = io.open({}, \"r\")\n  if plugin then\n    plugin:close()\n    local options = {{}}\n    for option in (hl.get_config(\"input.kb_options\") or \"\"):gmatch(\"[^,]+\") do\n      option = option:match(\"^%s*(.-)%s*$\")\n      if not option:find(\"caps\", 1, true) then\n        table.insert(options, option)\n      end\n    end\n    table.insert(options, \"{option}\")\n    hl.config({{ input = {{ kb_options = table.concat(options, \",\") }} }})\n  end\nend\n{END}",
        common::lua(&manifest.to_string_lossy())
    ))
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
    let starts = text.matches("-- BEGIN FAMILIAR CAPS LOCK").count();
    let ends = text.matches("-- END FAMILIAR CAPS LOCK").count();
    if starts == 0 && ends == 0 {
        return Ok((text.into(), "reset".into()));
    }
    if starts == 1 && ends == 1 {
        for mode in ["normal", "compose"] {
            let block = hook(mode, manifest)?;
            if let Some(start) = text.find(&block) {
                return Ok((
                    format!("{}{}", &text[..start], &text[start + block.len()..]),
                    mode.into(),
                ));
            }
        }
    }
    Err("Familiar Caps Lock block was edited, damaged or belongs to another installation; no file changed".into())
}

fn replace(path: &Path, content: &str, permissions: fs::Permissions) -> Result<()> {
    let mut temp =
        tempfile::NamedTempFile::new_in(path.parent().ok_or("Missing config directory")?)
            .map_err(|e| e.to_string())?;
    temp.write_all(content.as_bytes())
        .map_err(|e| e.to_string())?;
    temp.as_file()
        .set_permissions(permissions)
        .map_err(|e| e.to_string())?;
    temp.as_file().sync_all().map_err(|e| e.to_string())?;
    temp.persist(path).map_err(|e| e.to_string())?;
    Ok(())
}

fn reload(hypr: &mut impl Hypr) -> Result<()> {
    checked(hypr, &["reload"])?;
    let errors: Vec<String> = serde_json::from_str(&hypr.command(&["-j", "configerrors"])?)
        .map_err(|_| "Could not verify Hyprland configuration errors")?;
    if !errors.is_empty() {
        return Err(format!(
            "Hyprland configuration error: {}",
            common::clipped(&errors.join("; "))
        ));
    }
    Ok(())
}

pub fn change(mode: &str, paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    if !["normal", "compose", "reset", "status"].contains(&mode) {
        return Err("Usage: familiar-desktop caps-lock <normal|compose|reset|status>".into());
    }
    let _lock = if mode == "status" {
        None
    } else {
        Some(common::lock(&paths.state.join("config.lock"))?)
    };
    let before = text(&paths.config)?;
    let (clean, previous) = split(&before, &paths.manifest)?;
    if mode == "status" {
        return Ok(
            json!({"state":"ok","mode":previous,"message":"Saved preference; per-device keyboard overrides still take precedence."}),
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
                "assert(hl and hl.config and hl.get_config, 'Familiar Caps Lock requires Hyprland Lua configuration')",
            ],
        )?;
        format!("{}{}", clean, hook(mode, &paths.manifest)?)
    };
    let permissions = fs::metadata(&paths.config)
        .map_err(|e| e.to_string())?
        .permissions();
    let backup = if before != after {
        fs::create_dir_all(&paths.state).map_err(|e| e.to_string())?;
        let mut backup = tempfile::Builder::new()
            .prefix("hyprland-before-")
            .suffix(".lua")
            .tempfile_in(&paths.state)
            .map_err(|e| e.to_string())?;
        backup
            .write_all(before.as_bytes())
            .map_err(|e| e.to_string())?;
        backup.as_file().sync_all().map_err(|e| e.to_string())?;
        let (_, path) = backup.keep().map_err(|e| e.to_string())?;
        if text(&paths.config)? != before {
            return Err(
                "Hyprland config changed during setup; retry without discarding your edits".into(),
            );
        }
        replace(&paths.config, &after, permissions.clone())?;
        Some(path)
    } else {
        None
    };
    let applied = reload(hypr).and_then(|()| {
        if mode == "reset" { return Ok(()); }
        let option = if mode == "normal" { "caps:capslock" } else { "compose:caps" };
        checked(hypr, &["eval", &format!("assert((',' .. (hl.get_config('input.kb_options') or '') .. ','):find({}, 1, true), 'Caps Lock override did not apply')", common::lua(&format!(",{option},")))])
    });
    if let Err(error) = applied {
        if text(&paths.config)? != after {
            return Err(format!(
                "{error}. Config changed externally; preserve your edits and recover from {backup:?}"
            ));
        }
        replace(&paths.config, &before, permissions)?;
        let recovery = reload(hypr);
        return Err(format!(
            "{error}. Previous configuration restored on disk. Recovery reload: {}",
            recovery.err().unwrap_or_else(|| "ok".into())
        ));
    }
    Ok(
        json!({"state":"ok","mode":mode,"backup":backup,"message":if mode == "reset" { "Using your keyboard configuration again." } else { "Caps Lock preference applied. Per-device overrides still take precedence." }}),
    )
}

pub fn execute(args: &[String]) -> Result<Value> {
    if args.len() != 1 {
        return Err("Usage: familiar-desktop caps-lock <normal|compose|reset|status>".into());
    }
    change(&args[0], &Paths::system()?, &mut common::SystemHypr)
}
