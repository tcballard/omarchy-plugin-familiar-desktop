//! Own only the horizontal bar-size line in the machine-level shell override.
use crate::{Result, config_file};
use serde_json::{Value, json};
use std::{fs, io::Write, path::Path};

const HEIGHT: &str = "size-horizontal = 48 # Familiar Windows taskbar\n";

fn read_optional(path: &Path) -> Result<Option<String>> {
    match fs::symlink_metadata(path) {
        Ok(_) => config_file::read(path).map(Some),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

pub fn plan(path: &Path) -> Result<Value> {
    let original = read_optional(path)?;
    let before = original.as_deref().unwrap_or("");
    if before.contains("# Familiar Windows taskbar") {
        return Err(
            "Untracked Familiar taskbar height override; restore it before continuing".into(),
        );
    }
    let mut in_bar = false;
    let mut bar_end = None;
    let mut bar_count = 0;
    let mut key = None;
    let mut offset = 0;
    for line in before.split_inclusive('\n') {
        let trimmed = line.split('#').next().unwrap_or("").trim();
        if trimmed.starts_with('[') {
            if in_bar {
                bar_end = Some(offset);
            }
            in_bar = trimmed == "[bar]";
            if in_bar {
                bar_count += 1;
                bar_end = Some(offset + line.len());
            }
        } else if in_bar && trimmed.split('=').next().unwrap_or("").trim() == "size-horizontal" {
            if key.is_some() {
                return Err("Duplicate bar height settings; no changes made".into());
            }
            key = Some((offset, line));
        }
        offset += line.len();
        if in_bar {
            bar_end = Some(offset);
        }
    }
    if bar_count > 1 {
        return Err("Duplicate bar sections; no changes made".into());
    }
    // Avoid modifying TOML forms the shell itself does not support.
    if before.contains("\"\"\"") || before.contains("'''") || before.contains("[[") {
        return Err("Complex shell override syntax; taskbar height was left unchanged".into());
    }
    let (after, old_line) = if let Some((start, line)) = key {
        (
            format!(
                "{}{}{}",
                &before[..start],
                HEIGHT,
                &before[start + line.len()..]
            ),
            line,
        )
    } else if let Some(end) = bar_end {
        let separator = if end > 0 && !before[..end].ends_with('\n') {
            "\n"
        } else {
            ""
        };
        (
            format!("{}{separator}{HEIGHT}{}", &before[..end], &before[end..]),
            "",
        )
    } else {
        let separator = if before.is_empty() || before.ends_with('\n') {
            ""
        } else {
            "\n"
        };
        (format!("{before}{separator}[bar]\n{HEIGHT}"), "")
    };
    Ok(
        json!({"present":original.is_some(),"before":before,"after":after,"oldLine":old_line,"createdSection":bar_count == 0}),
    )
}

pub fn apply(path: &Path, saved: &Value, state: &Path) -> Result<()> {
    let before = saved["before"]
        .as_str()
        .ok_or("Missing previous taskbar style")?;
    let after = saved["after"]
        .as_str()
        .ok_or("Missing installed taskbar style")?;
    if saved["present"] == true {
        config_file::replace(path, before, after, state)?;
    } else {
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(path)
            .map_err(|e| e.to_string())?;
        file.write_all(after.as_bytes())
            .map_err(|e| e.to_string())?;
        file.sync_all().map_err(|e| e.to_string())?;
    }
    Ok(())
}

pub fn restore(path: &Path, saved: &Value, state: &Path) -> Result<()> {
    let Some(current) = read_optional(path)? else {
        return Ok(());
    };
    let before = saved["before"]
        .as_str()
        .ok_or("Missing previous taskbar style")?;
    let after = saved["after"]
        .as_str()
        .ok_or("Missing installed taskbar style")?;
    if current == after {
        // Keep an empty override file if we created it; it inherits the theme.
        config_file::replace(path, &current, before, state)?;
        return Ok(());
    }
    // Preserve subsequent edits, including a user-selected different height.
    let matches = current
        .split_inclusive('\n')
        .filter(|line| *line == HEIGHT)
        .count();
    if matches == 0 {
        return Ok(());
    }
    if matches != 1 {
        return Err("Duplicated Familiar height override; recovery record retained".into());
    }
    let old = saved["oldLine"]
        .as_str()
        .ok_or("Missing previous height setting")?;
    let replacement = if old.is_empty() || old.ends_with('\n') {
        old.to_owned()
    } else {
        format!("{old}\n")
    };
    let mut restored = current.replacen(HEIGHT, &replacement, 1);
    if saved["createdSection"] == true && restored.ends_with("[bar]\n") {
        restored.truncate(restored.len() - "[bar]\n".len());
    }
    config_file::replace(path, &current, &restored, state)?;
    Ok(())
}
