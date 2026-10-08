//! Reversible native-bar placement. Only owned fields/entries are restored;
//! unrelated shell preferences and widget settings remain user-owned.
use crate::{Result, common, config_file, taskbar_style};
use serde_json::{Value, json};
use std::{fs, path::Path};

const ID: &str = "io.github.tcballard.familiar-desktop";
const SECTIONS: [&str; 3] = ["left", "center", "right"];
fn id(v: &Value) -> &str {
    v.as_str()
        .or_else(|| v.get("id").and_then(Value::as_str))
        .unwrap_or("")
}
fn locate(layout: &Value, key: &str) -> Vec<(String, usize)> {
    let mut found = Vec::new();
    for section in SECTIONS {
        if let Some(entries) = layout[section].as_array() {
            for (index, entry) in entries.iter().enumerate() {
                if id(entry) == key {
                    found.push((section.into(), index));
                }
            }
        }
    }
    found
}
fn valid(config: &Value) -> Result<()> {
    if config["version"] != 1
        || !config["bar"].is_object()
        || SECTIONS
            .iter()
            .any(|s| !config["bar"]["layout"][s].is_array())
    {
        return Err(
            "Expected a version 1 shell configuration with three bar sections; no changes made"
                .into(),
        );
    }
    Ok(())
}
fn read_json(path: &Path) -> Result<(String, Value)> {
    let text = config_file::read(path)?;
    let value = serde_json::from_str(&text).map_err(|e| format!("Invalid configuration: {e}"))?;
    Ok((text, value))
}
fn encode(value: &Value) -> Result<String> {
    serde_json::to_string_pretty(value)
        .map(|s| s + "\n")
        .map_err(|e| e.to_string())
}
fn response(enabled: bool) -> Value {
    json!({"state":"ok","mode":if enabled {"enable"} else {"reset"},
        "message":if enabled {"Windows taskbar uses one bottom bar. Choose General or Mac to restore your bar."} else {"Previous bar placement restored; later personal changes are preserved."}})
}

pub fn change(mode: &str, config_path: &Path, state_dir: &Path) -> Result<Value> {
    if !["enable", "reset", "status"].contains(&mode) {
        return Err("Choose enable, reset or status".into());
    }
    let _lock = common::lock(&state_dir.join("config.lock"))?;
    let receipt_path = state_dir.join("placement.json");
    let style_path = config_path.with_extension("toml");
    let receipt = match fs::symlink_metadata(&receipt_path) {
        Ok(_) => Some(read_json(&receipt_path)?.1),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
        Err(e) => return Err(e.to_string()),
    };
    if receipt.is_none() && mode != "enable" {
        return Ok(response(false));
    }
    let (before, mut config) = read_json(config_path)?;
    valid(&config)?;
    if let Some(ref saved) = receipt {
        if saved["version"] != 1 || !saved["moves"].is_array() || !saved["position"].is_object() {
            return Err("Invalid taskbar recovery record; retained for manual recovery".into());
        }
        let enabled = config["bar"]
            .get("id")
            .is_none_or(|v| v == "omarchy.bar" || v == "")
            && config["bar"]["position"] == "bottom"
            && locate(&config["bar"]["layout"], ID).len() == 1;
        if mode == "status" {
            return Ok(response(enabled));
        }
        if mode == "enable" {
            return if enabled {
                // Upgrade an active pre-hotfix taskbar without losing its restore record.
                if saved.get("style").is_none() {
                    let style = taskbar_style::plan(&style_path)?;
                    let mut upgraded = saved.clone();
                    upgraded["style"] = style.clone();
                    common::atomic(&receipt_path, encode(&upgraded)?.as_bytes())?;
                    taskbar_style::apply(&style_path, &style, state_dir)?;
                }
                Ok(response(true))
            } else {
                Err("Bar changed since taskbar setup. Select General to restore owned settings before enabling again.".into())
            };
        }
        // Restore only a value that still matches what we installed.
        if config["bar"]["position"] == "bottom" {
            if saved["position"]["present"] == true {
                config["bar"]["position"] = saved["position"]["value"].clone();
            } else {
                config["bar"].as_object_mut().unwrap().remove("position");
            }
        }
        for movement in saved["moves"].as_array().unwrap().iter().rev() {
            let key = movement["id"]
                .as_str()
                .ok_or("Invalid taskbar entry record")?;
            let original = movement["section"]
                .as_str()
                .ok_or("Invalid original section")?;
            let installed = movement["installedSection"]
                .as_str()
                .ok_or("Invalid installed section")?;
            if !SECTIONS.contains(&original)
                || !SECTIONS.contains(&installed)
                || ![ID, "omarchy.clock"].contains(&key)
            {
                return Err("Invalid taskbar placement record".into());
            }
            let positions = locate(&config["bar"]["layout"], key);
            // User removed, duplicated or moved the entry: leave that choice intact.
            if positions.len() != 1 || positions[0].0 != installed {
                continue;
            }
            let (section, index) = &positions[0];
            let item = config["bar"]["layout"][section]
                .as_array_mut()
                .unwrap()
                .remove(*index);
            let target = config["bar"]["layout"][original].as_array_mut().unwrap();
            let next_id = movement["next"].as_str().unwrap_or("");
            let previous_id = movement["previous"].as_str().unwrap_or("");
            let index = target
                .iter()
                .position(|v| !next_id.is_empty() && id(v) == next_id)
                .or_else(|| {
                    target
                        .iter()
                        .position(|v| !previous_id.is_empty() && id(v) == previous_id)
                        .map(|i| i + 1)
                })
                .unwrap_or_else(|| {
                    (movement["index"].as_u64().unwrap_or(0) as usize).min(target.len())
                });
            target.insert(index, item);
        }
        // A service/drawer-only install needs a temporary bar entry. Remove
        // only our unchanged entry; retain later user moves or inline settings.
        if saved["insertedFamiliar"] == true {
            let positions = locate(&config["bar"]["layout"], ID);
            if positions.len() == 1 && positions[0].0 == "left" {
                let index = positions[0].1;
                let entries = config["bar"]["layout"]["left"].as_array_mut().unwrap();
                if entries[index] == json!({"id": ID}) {
                    entries.remove(index);
                }
            }
        }
        config_file::replace(config_path, &before, &encode(&config)?, state_dir)?;
        if let Some(style) = saved.get("style") {
            taskbar_style::restore(&style_path, style, state_dir)?;
        }
        fs::remove_file(receipt_path).map_err(|e| e.to_string())?;
        return Ok(response(false));
    }
    let bar_id = config["bar"]["id"].as_str().unwrap_or("omarchy.bar");
    if bar_id != "omarchy.bar" && !bar_id.is_empty() {
        return Err("Windows taskbar currently requires the built-in Omarchy bar. Your custom bar was left unchanged.".into());
    }
    let familiar_positions = locate(&config["bar"]["layout"], ID);
    if familiar_positions.len() > 1 {
        return Err("Duplicate bar entries; no changes made".into());
    }
    // Some Omarchy revisions treat a combined service/widget in `plugins` as
    // already enabled, even with explicit bar placement. A drawer also keeps
    // its widget outside bar.layout. Own the missing entry in this transaction
    // rather than relying on enablePlugin or changing the user's drawer.
    let inserted_familiar = familiar_positions.is_empty();
    if inserted_familiar {
        config["bar"]["layout"]["left"]
            .as_array_mut()
            .unwrap()
            .push(json!({"id": ID}));
    }
    let position = json!({"present":config["bar"].get("position").is_some(),"value":config["bar"]["position"]});
    let mut moves = Vec::new();
    for (key, destination) in [(ID, "left"), ("omarchy.clock", "right")] {
        let positions = locate(&config["bar"]["layout"], key);
        if positions.len() > 1 {
            return Err("Duplicate bar entries; no changes made".into());
        }
        let Some((section, index)) = positions.first() else {
            continue;
        };
        if section == destination {
            continue;
        }
        let entries = config["bar"]["layout"][section].as_array_mut().unwrap();
        moves.push(
            json!({"id":key,"section":section,"index":index,"installedSection":destination,
            "previous":index.checked_sub(1).map(|i|id(&entries[i])).unwrap_or(""),
            "next":entries.get(index+1).map(id).unwrap_or("")}),
        );
        let item = entries.remove(*index);
        config["bar"]["layout"][destination]
            .as_array_mut()
            .unwrap()
            .push(item);
    }
    config["bar"]["position"] = json!("bottom");
    let style = taskbar_style::plan(&style_path)?;
    let saved = json!({"version":1,"position":position,"moves":moves,"style":style,
        "insertedFamiliar":inserted_familiar});
    // Write recovery information first: an interrupted enable is recoverable.
    common::atomic(&receipt_path, encode(&saved)?.as_bytes())?;
    taskbar_style::apply(&style_path, &saved["style"], state_dir)?;
    config_file::replace(config_path, &before, &encode(&config)?, state_dir)?;
    Ok(response(true))
}

pub fn execute(args: &[String]) -> Result<Value> {
    if args.len() != 1 {
        return Err("Usage: familiar-desktop taskbar <enable|reset|status>".into());
    }
    let home = common::home()?;
    if args[0] == "enable" && home.join(".local/state/omarchy/toggles/bar-off").exists() {
        return Err("Show Omarchy’s bar before enabling Windows taskbar.".into());
    }
    change(
        &args[0],
        &home.join(".config/omarchy/shell.json"),
        &home.join(".local/state/familiar-desktop/taskbar"),
    )
}
