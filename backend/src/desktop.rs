//! User-requested desktop actions. Journal before moving anything; never replay
//! a window address across compositor sessions or against a different process.
use crate::{
    Result,
    common::{self, Hypr, checked, lua},
    dock,
};
use serde_json::{Value, json};
use std::{
    env, fs,
    path::Path,
    time::{Duration, Instant},
};

const HIDDEN: &str = "special:familiar-desktop";
fn clients(h: &mut impl Hypr) -> Result<Vec<Value>> {
    serde_json::from_str(&h.command(&["-j", "clients"])?).map_err(|_| "Invalid window list".into())
}
fn same(entry: &Value, window: &Value) -> bool {
    ["address", "pid", "initialClass"]
        .iter()
        .all(|k| entry[*k] == window[*k])
}
fn valid_window(c: &Value) -> bool {
    dock::valid_address(c["address"].as_str().unwrap_or(""))
        && c["pid"].as_u64().is_some_and(|p| p > 1)
}
fn move_to(h: &mut impl Hypr, c: &Value, workspace: &str) -> Result<()> {
    checked(
        h,
        &[
            "dispatch",
            &format!(
                "hl.dsp.window.move({{window={}, workspace={}}})",
                lua(&format!(
                    "address:{}",
                    c["address"].as_str().ok_or("Missing address")?
                )),
                lua(workspace)
            ),
        ],
    )
}
fn save(path: &Path, j: &Value) -> Result<()> {
    common::atomic(path, &serde_json::to_vec(j).map_err(|e| e.to_string())?)
}

pub fn show_desktop(mode: &str, path: &Path, session: &str, h: &mut impl Hypr) -> Result<Value> {
    if !["show", "restore"].contains(&mode) || session.is_empty() {
        return Err("A running Hyprland session is required".into());
    }
    let _lock = common::lock(&path.with_extension("lock"))?;
    let mut journal = common::read_json(path)?;
    if journal.get("session").is_some() && journal["session"] != session {
        // A compositor restart destroys the old window identities.
        journal = json!({});
        save(path, &journal)?;
    }
    let windows = clients(h)?;
    if mode == "show" {
        if journal["windows"].as_array().is_some_and(|a| !a.is_empty()) {
            return Err("Restore the previous desktop before hiding more windows".into());
        }
        let monitors: Vec<Value> = serde_json::from_str(&h.command(&["-j", "monitors"])?)
            .map_err(|_| "Invalid monitor list")?;
        let selected: Vec<Value> = windows.iter().filter(|c| {
            valid_window(c) && c["mapped"] != false && c["pinned"] != true && c["workspace"]["id"].as_i64().is_some_and(|id| id > 0)
                && monitors.iter().any(|m| m["activeWorkspace"]["id"] == c["workspace"]["id"])
        }).map(|c| json!({"address":c["address"],"pid":c["pid"],"initialClass":c["initialClass"],"workspace":c["workspace"]["name"]})).collect();
        if selected.len() > 128
            || selected.iter().any(|c| {
                c["workspace"]
                    .as_str()
                    .is_none_or(|s| s.is_empty() || s.len() > 200)
            })
        {
            return Err("Cannot safely record this desktop".into());
        }
        let active: Value = serde_json::from_str(&h.command(&["-j", "activewindow"])?)
            .map_err(|_| "Invalid active window")?;
        journal = json!({"schemaVersion":1,"session":session,"active":active["address"],"windows":selected});
        save(path, &journal)?;
        let started = Instant::now();
        for c in journal["windows"].as_array().unwrap() {
            if started.elapsed() > Duration::from_secs(20) {
                return Err("Hide interrupted. Use Restore windows to recover.".into());
            }
            // Re-query before each action, so closed/replaced windows aren't targeted.
            if clients(h)?
                .iter()
                .any(|w| same(c, w) && w["workspace"]["name"] == c["workspace"])
            {
                move_to(h, c, HIDDEN)
                    .map_err(|e| format!("{e}. Use Restore windows to recover."))?;
            }
        }
        return Ok(
            json!({"state":"ok","message":"Desktop shown. Restore windows brings them back."}),
        );
    }
    let entries = journal["windows"].as_array().cloned().unwrap_or_default();
    if !entries.is_empty() && journal["schemaVersion"] != 1 {
        return Err("Unknown recovery journal version".into());
    }
    if entries.len() > 128
        || entries.iter().any(|c| {
            !valid_window(c)
                || c["workspace"]
                    .as_str()
                    .is_none_or(|s| s.is_empty() || s.starts_with("special:") || s.len() > 200)
        })
    {
        return Err("Invalid recovery journal; no windows moved".into());
    }
    let mut remaining = Vec::new();
    let mut restored = Vec::new();
    let started = Instant::now();
    for c in entries {
        if started.elapsed() > Duration::from_secs(20) {
            remaining.push(c);
            continue;
        }
        let current = clients(h)?;
        if current
            .iter()
            .any(|w| same(&c, w) && w["workspace"]["name"] == HIDDEN)
        {
            match move_to(h, &c, c["workspace"].as_str().unwrap()) {
                Ok(()) => restored.push(c),
                Err(_) => remaining.push(c),
            }
        }
        // Closed windows and windows manually restored/moved are left alone.
    }
    journal["windows"] = json!(remaining);
    save(path, &journal)?;
    if !remaining.is_empty() {
        return Err("Some windows could not be restored. Retry Restore windows.".into());
    }
    if let Some(c) = restored.iter().find(|c| c["address"] == journal["active"]) {
        checked(
            h,
            &[
                "dispatch",
                &format!(
                    "hl.dsp.focus({{window={}}})",
                    lua(&format!("address:{}", c["address"].as_str().unwrap()))
                ),
            ],
        )?;
    }
    Ok(json!({"state":"ok","message":"Windows restored."}))
}

pub fn quit_targets(address: &str, windows: &[Value]) -> Result<Vec<Value>> {
    if !dock::valid_address(address) {
        return Err("Select a valid window".into());
    }
    let selected = windows
        .iter()
        .find(|w| w["address"] == address && valid_window(w))
        .ok_or("That window has closed")?;
    Ok(windows
        .iter()
        .filter(|w| valid_window(w) && w["pid"] == selected["pid"])
        .cloned()
        .collect())
}
pub fn quit_app(address: &str, h: &mut impl Hypr) -> Result<Value> {
    let targets = quit_targets(address, &clients(h)?)?;
    if targets.len() > 128 {
        return Err("Too many windows; use Task Manager".into());
    }
    for c in targets {
        if clients(h)?.iter().any(|w| same(&c, w)) {
            checked(
                h,
                &[
                    "dispatch",
                    &format!(
                        "hl.dsp.window.close({{window={}}})",
                        lua(&format!("address:{}", c["address"].as_str().unwrap()))
                    ),
                ],
            )?;
        }
    }
    Ok(
        json!({"state":"ok","message":"Close requested for this application's windows. Check for save prompts."}),
    )
}

fn shortcut_keys(b: &Value) -> String {
    let mask = b["modmask"].as_u64().unwrap_or(0);
    let mut keys: Vec<String> = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
        .iter()
        .filter(|(bit, _)| mask & bit != 0)
        .map(|(_, s)| s.to_string())
        .collect();
    keys.push(
        b["key"]
            .as_str()
            .filter(|s| !s.is_empty())
            .map(common::clipped)
            .unwrap_or_else(|| format!("code:{}", b["keycode"])),
    );
    keys.join(" + ")
}

pub fn shortcuts(h: &mut impl Hypr) -> Result<Value> {
    let bindings: Vec<Value> = serde_json::from_str(&h.command(&["-j", "binds"])?)
        .map_err(|_| "Cannot read active shortcuts")?;
    let rows: Vec<Value> = bindings.iter().filter(|b| b["description"].as_str().is_some_and(|s| !s.is_empty())).take(200).map(|b| {
        json!({"keys":shortcut_keys(b),"description":common::clipped(b["description"].as_str().unwrap()),"submap":common::clipped(b["submap"].as_str().unwrap_or(""))})
    }).collect();
    // Keep all chords for the coach, including undescribed ones: another action
    // on the same chord makes an otherwise valid lesson ambiguous. Reuse the
    // existing canonical modifier order; display terminology remains in QML.
    let coach_bindings: Vec<Value> = bindings.iter().take(2048).map(|b| {
        let mask = b["modmask"].as_u64().unwrap_or(0);
        let key = b["key"].as_str().filter(|s| !s.is_empty()).map(common::clipped).unwrap_or_else(|| format!("code:{}",b["keycode"]));
        json!({"keys":shortcut_keys(b),"key":key,"description":common::clipped(b["description"].as_str().unwrap_or("")),
            "dispatcher":b["dispatcher"],"arg":b["arg"],"submap":b["submap"].as_str().unwrap_or(""),
            "mouse":b["mouse"] == true || mask & !77 != 0,"release":b["release"],"longPress":b["longPress"],"catch_all":b["catch_all"]})
    }).collect();
    // Never teach from a truncated snapshot that may have omitted conflicts.
    let coach_bindings = if bindings.len() > 2048 {
        vec![]
    } else {
        coach_bindings
    };
    Ok(json!({"state":"ok","shortcuts":rows,"coachBindings":coach_bindings,"tools":tool_status()}))
}

pub fn execute(args: &[String]) -> Result<Value> {
    let mut h = common::SystemHypr;
    match args.first().map(String::as_str) {
        Some("show" | "restore" | "prepare-remove") if args.len() == 1 => {
            let state = env::var_os("XDG_STATE_HOME")
                .map(std::path::PathBuf::from)
                .unwrap_or(common::home()?.join(".local/state"));
            let result = show_desktop(
                if args[0] == "prepare-remove" {
                    "restore"
                } else {
                    &args[0]
                },
                &state.join("omarchy/familiar-desktop-recovery.json"),
                &env::var("HYPRLAND_INSTANCE_SIGNATURE").unwrap_or_default(),
                &mut h,
            )?;
            if args[0] == "prepare-remove" {
                ensure_removable(&clients(&mut h)?)?;
            }
            Ok(result)
        }
        Some("quit-app") if args.len() == 2 => quit_app(&args[1], &mut h),
        Some("shortcuts") if args.len() == 1 => shortcuts(&mut h),
        Some("open-tool") if args.len() == 2 => open_tool(&args[1]),
        Some("force-quit") if args.len() == 3 && args[2] == "--confirm" => {
            force_quit(&args[1], &mut h)
        }
        _ => Err(
            "Usage: desktop <show|restore|shortcuts|quit-app ADDRESS|force-quit ADDRESS --confirm>"
                .into(),
        ),
    }
}

pub fn ensure_removable(windows: &[Value]) -> Result<()> {
    if windows.iter().any(|w| {
        matches!(
            w["workspace"]["name"].as_str(),
            Some("special:minimized" | "special:familiar-desktop")
        )
    }) {
        return Err("Hidden windows remain. Restore minimised windows from the dock before uninstalling; no plugin files removed".into());
    }
    Ok(())
}

fn force_quit(address: &str, h: &mut impl Hypr) -> Result<Value> {
    use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
    use std::os::unix::fs::MetadataExt;
    let target = quit_targets(address, &clients(h)?)?
        .into_iter()
        .find(|c| c["address"] == address)
        .ok_or("Window has closed")?;
    let pid = target["pid"]
        .as_i64()
        .filter(|p| *p > 1 && *p <= i32::MAX as i64)
        .ok_or("Invalid application process")? as i32;
    // Open a stable process handle first; do not use kill(pid) or class matching.
    let fd = unsafe { libc::syscall(libc::SYS_pidfd_open, pid, 0) } as i32;
    if fd < 0 {
        return Err("Cannot identify this process safely; use Task Manager".into());
    }
    let handle = unsafe { OwnedFd::from_raw_fd(fd) };
    let meta = fs::metadata(format!("/proc/{pid}")).map_err(|_| "Application has exited")?;
    if meta.uid() != unsafe { libc::getuid() } || pid == std::process::id() as i32 {
        return Err("Cannot force quit that process".into());
    }
    if !clients(h)?.iter().any(|w| same(&target, w)) {
        return Err("Window changed; select it again".into());
    }
    let result = unsafe {
        libc::syscall(
            libc::SYS_pidfd_send_signal,
            handle.as_raw_fd(),
            libc::SIGKILL,
            std::ptr::null::<libc::siginfo_t>(),
            0,
        )
    };
    if result < 0 {
        return Err(std::io::Error::last_os_error().to_string());
    }
    Ok(json!({"state":"ok","message":"Application process stopped."}))
}

fn tool_argv(key: &str) -> Result<Vec<&'static str>> {
    match key {
        "store" => Ok(vec!["omastore"]),
        "task-manager" => Ok(vec!["omarchy-task-manager"]),
        "settings" => Ok(vec!["omarchy-menu", "summon", "setup"]),
        "help" => Ok(vec![
            "xdg-open",
            "https://github.com/tcballard/omarchy-plugin-familiar-desktop/blob/main/docs/TROUBLESHOOTING.md",
        ]),
        _ => Err("Unknown companion tool".into()),
    }
}
fn available(command: &str) -> bool {
    use std::os::unix::fs::PermissionsExt;
    env::split_paths(&env::var_os("PATH").unwrap_or_default()).any(|dir| {
        fs::metadata(dir.join(command))
            .is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
    })
}
fn tool_status() -> Value {
    json!(
        ["store", "task-manager", "settings", "help"]
            .map(|key| json!({"key":key,"available":available(tool_argv(key).unwrap()[0])}))
    )
}
fn open_tool(key: &str) -> Result<Value> {
    use std::process::{Command, Stdio};
    let args = tool_argv(key)?;
    if !available(args[0]) {
        return Err(format!(
            "{} is not installed or is not on PATH. Install it separately, then try again.",
            args[0]
        ));
    }
    Command::new(args[0])
        .args(&args[1..])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(json!({"state":"ok","message":"Launch requested."}))
}
