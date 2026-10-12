//! Explicit paste only. Clipboard owners are untrusted and may never close stdout.
use crate::Result;
use serde_json::{Value, json};
use std::{
    io::Read,
    os::fd::AsRawFd,
    os::unix::process::CommandExt,
    process::{Command, Stdio},
    time::{Duration, Instant},
};

const MAX_BYTES: usize = 16 * 1024;
const TIMEOUT: Duration = Duration::from_secs(2);

fn receive(command: &mut Command, limit: usize, timeout: Duration) -> Result<String> {
    let parent = std::process::id() as libc::pid_t;
    // A shell reload may terminate this helper while a hostile owner is still
    // streaming. Do not leave wl-paste orphaned when its supervisor disappears.
    unsafe {
        command.pre_exec(move || {
            if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGKILL) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            if libc::getppid() != parent {
                return Err(std::io::Error::other("Clipboard supervisor exited"));
            }
            Ok(())
        });
    }
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("Could not start clipboard reader: {e}"))?;
    let result = (|| {
        let mut output = child.stdout.take().ok_or("Clipboard output unavailable")?;
        let fd = output.as_raw_fd();
        // Nonblocking reads plus a total deadline also bound a slow, endless owner.
        let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
        if flags < 0 || unsafe { libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0 {
            return Err("Could not bound clipboard reader".into());
        }
        let deadline = Instant::now() + timeout;
        let mut bytes = Vec::new();
        loop {
            if Instant::now() >= deadline {
                return Err("Clipboard read timed out".into());
            }
            let mut buffer = [0u8; 4096];
            match output.read(&mut buffer) {
                Ok(0) => break,
                Ok(n) => {
                    if bytes.len() + n > limit {
                        return Err("Clipboard text exceeds 16 KiB".into());
                    }
                    bytes.extend_from_slice(&buffer[..n]);
                }
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    let mut poll = libc::pollfd {
                        fd,
                        events: libc::POLLIN,
                        revents: 0,
                    };
                    unsafe {
                        libc::poll(&mut poll, 1, 20);
                    }
                }
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {}
                Err(_) => return Err("Could not read clipboard text".into()),
            }
        }
        loop {
            match child.try_wait().map_err(|e| e.to_string())? {
                Some(status) if status.success() => break,
                Some(_) => return Err("No readable clipboard text".into()),
                None if Instant::now() >= deadline => return Err("Clipboard read timed out".into()),
                None => std::thread::sleep(Duration::from_millis(10)),
            }
        }
        String::from_utf8(bytes).map_err(|_| "Clipboard text is not UTF-8".into())
    })();
    // Reap on every path, including overflow and timeout. Never return partial data.
    let _ = child.kill();
    let _ = child.wait();
    result
}

pub fn paste() -> Result<Value> {
    let text = receive(
        Command::new("wl-paste").args(["--no-newline", "--type", "text"]),
        MAX_BYTES,
        TIMEOUT,
    )?;
    Ok(json!({"state":"ok", "text":text}))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn shell(script: &str, limit: usize, timeout: Duration) -> Result<String> {
        receive(Command::new("sh").args(["-c", script]), limit, timeout)
    }
    #[test]
    fn complete_text_only() {
        assert_eq!(shell("printf hello", 5, TIMEOUT).unwrap(), "hello");
        assert!(shell("printf hello; exit 1", 5, TIMEOUT).is_err());
        assert!(shell("printf '\\377'", 5, TIMEOUT).is_err());
    }
    #[test]
    fn hostile_streams_are_bounded() {
        assert!(
            shell("while :; do printf 1234567890; done", 32, TIMEOUT)
                .unwrap_err()
                .contains("exceeds")
        );
        let started = Instant::now();
        assert!(
            shell("while :; do :; done", 32, Duration::from_millis(50))
                .unwrap_err()
                .contains("timed out")
        );
        assert!(started.elapsed() < Duration::from_secs(2));
    }
}
