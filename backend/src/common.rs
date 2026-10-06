use crate::Result;
use serde_json::{Value, json};
use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    os::unix::{fs::OpenOptionsExt, io::AsRawFd, process::CommandExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant},
};

pub const FILE_LIMIT: usize = 256 * 1024;
pub const OUTPUT_LIMIT: usize = 1024 * 1024;
pub fn home() -> Result<PathBuf> {
    env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| "HOME is unavailable".into())
}
pub fn config_home() -> Result<PathBuf> {
    Ok(env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or(home()?.join(".config")))
}
pub fn bounded_file(path: &Path, limit: usize) -> Result<Vec<u8>> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NONBLOCK)
        .open(path)
        .map_err(|e| e.to_string())?;
    if !file.metadata().map_err(|e| e.to_string())?.is_file() {
        return Err("Settings must be a regular file".into());
    }
    let mut data = Vec::new();
    file.take((limit + 1) as u64)
        .read_to_end(&mut data)
        .map_err(|e| e.to_string())?;
    if data.len() > limit {
        return Err(format!("File exceeds {limit} bytes"));
    }
    Ok(data)
}
pub fn read_json(path: &Path) -> Result<Value> {
    match bounded_file(path, FILE_LIMIT) {
        Ok(data) => {
            let v: Value =
                serde_json::from_slice(&data).map_err(|e| format!("Invalid JSON: {e}"))?;
            if !v.is_object() {
                return Err("Expected settings object".into());
            }
            Ok(v)
        }
        Err(_) if !path.exists() => Ok(json!({})),
        Err(e) => Err(e),
    }
}
pub fn atomic(path: &Path, data: &[u8]) -> Result<()> {
    let parent = path.parent().ok_or("Missing parent directory")?;
    fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let mut temp = tempfile::NamedTempFile::new_in(parent).map_err(|e| e.to_string())?;
    temp.write_all(data).map_err(|e| e.to_string())?;
    temp.as_file().sync_all().map_err(|e| e.to_string())?;
    temp.persist(path).map_err(|e| e.to_string())?;
    Ok(())
}
pub fn lua(value: &str) -> String {
    let mut out = String::from("\"");
    for c in value.chars() {
        match c {
            '"' | '\\' => {
                out.push('\\');
                out.push(c);
            }
            c if c.is_control() && (c as u32) < 128 => out.push_str(&format!("\\{:03}", c as u32)),
            _ => out.push(c),
        }
    }
    out.push('"');
    out
}
pub fn shell_quote(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\\''"))
}
pub fn clipped(s: &str) -> String {
    s.chars().take(300).collect()
}
fn nonblocking(fd: i32) -> Result<()> {
    // SAFETY: fd belongs to a retained pipe; fcntl does not transfer ownership.
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 || unsafe { libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0 {
        return Err(std::io::Error::last_os_error().to_string());
    }
    Ok(())
}
fn drain(reader: &mut impl Read, data: &mut Vec<u8>) -> Result<bool> {
    let mut buf = [0u8; 8192];
    // Bound work per tick so a continuously writing child cannot starve deadline checks.
    for _ in 0..16 {
        match reader.read(&mut buf) {
            Ok(0) => return Ok(true),
            Ok(n) => {
                if data.len() + n > OUTPUT_LIMIT {
                    return Err("Command response exceeded 1 MiB".into());
                }
                data.extend_from_slice(&buf[..n]);
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => return Ok(false),
            Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(e.to_string()),
        }
    }
    Ok(false)
}
pub fn run(program: &str, args: &[String], timeout: Duration) -> Result<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0)
        .spawn()
        .map_err(|e| e.to_string())?;
    let pid = child.id() as i32;
    let mut stdout = child.stdout.take().ok_or("Missing stdout")?;
    let mut stderr = child.stderr.take().ok_or("Missing stderr")?;
    let mut out = Vec::new();
    let mut err = Vec::new();
    let result = (|| {
        nonblocking(stdout.as_raw_fd())?;
        nonblocking(stderr.as_raw_fd())?;
        let deadline = Instant::now() + timeout;
        let mut out_done = false;
        let mut err_done = false;
        loop {
            if Instant::now() >= deadline {
                return Err("Command timed out".into());
            }
            if !out_done {
                out_done = drain(&mut stdout, &mut out)?;
            }
            if !err_done {
                err_done = drain(&mut stderr, &mut err)?;
            }
            // Do not reap the leader while descendants could still hold pipes.
            if out_done
                && err_done
                && let Some(status) = child.try_wait().map_err(|e| e.to_string())?
            {
                if !status.success() {
                    return Ok((false, status));
                }
                return Ok((true, status));
            }
            thread::sleep(Duration::from_millis(2));
        }
    })();
    match result {
        Ok((true, _)) => Ok(String::from_utf8_lossy(&out).into_owned()),
        Ok((false, _)) => Err(clipped(
            String::from_utf8_lossy(if err.is_empty() { &out } else { &err }).trim(),
        )),
        Err(e) => {
            // SAFETY: unreaped child retains this process-group identity. Kill descendants
            // before waiting, avoiding a delayed signal against a recycled PID.
            unsafe {
                libc::kill(-pid, libc::SIGKILL);
            }
            let _ = child.wait();
            Err(e)
        }
    }
}
pub trait Hypr {
    fn command(&mut self, args: &[&str]) -> Result<String>;
}
pub struct SystemHypr;
impl Hypr for SystemHypr {
    fn command(&mut self, args: &[&str]) -> Result<String> {
        run(
            "hyprctl",
            &args.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
            Duration::from_secs(8),
        )
    }
}
pub fn checked(hypr: &mut impl Hypr, args: &[&str]) -> Result<()> {
    let value = hypr.command(args)?;
    if value.trim().eq_ignore_ascii_case("ok") {
        Ok(())
    } else {
        Err(clipped(value.trim()))
    }
}
pub fn lock(path: &Path) -> Result<File> {
    fs::create_dir_all(path.parent().ok_or("Missing parent")?).map_err(|e| e.to_string())?;
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .mode(0o600)
        .open(path)
        .map_err(|e| e.to_string())?;
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        // SAFETY: file owns the descriptor throughout the lock lifetime.
        if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } == 0 {
            return Ok(file);
        }
        if Instant::now() >= deadline {
            return Err("Another Familiar operation is busy".into());
        }
        thread::sleep(Duration::from_millis(10));
    }
}
pub fn save_badges(home: &Path, raw: &str) -> Result<Value> {
    if raw.len() > FILE_LIMIT {
        return Err("Badge state exceeds 256 KiB".into());
    }
    let value: Value = serde_json::from_str(raw).map_err(|e| e.to_string())?;
    if !value.is_object() || !value["counts"].is_object() || !value["urgent"].is_object() {
        return Err("Expected badge counts and urgent objects".into());
    }
    atomic(
        &home.join(".local/state/omarchy/familiar-desktop-badges.json"),
        raw.as_bytes(),
    )?;
    Ok(json!({"state":"ok"}))
}

/// Read private badge data from a bounded pipe, never the process argument list.
pub fn save_badges_from_reader(home: &Path, reader: impl Read) -> Result<Value> {
    let mut raw = String::new();
    reader
        .take((FILE_LIMIT + 1) as u64)
        .read_to_string(&mut raw)
        .map_err(|_| "Unable to read badge state".to_string())?;
    save_badges(home, &raw)
}
