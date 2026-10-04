# Familiar v0.1.0-rc.2 — XPS acceptance

This is the v0.1.0 desktop candidate. Automated tests use fixtures; this checklist records actual Omarchy/Hyprland behavior. It does not include Familiar Paint, a Windows taskbar redesign or a macOS window-preview redesign.

## Install

Download and extract the `familiar-desktop-release` ZIP from the candidate PR's successful **Release binaries** workflow. From that extracted folder:

```bash
bash install-candidate.sh windows
```

Use `mac` for left-side controls. This installs the exact commit embedded in the bundle, with a static prebuilt Rust helper and the prebuilt Hyprbars library. No Rust, Clippy, compiler, Hyprpm or Hyprland checkout is needed. Linux x86_64 and the Hyprland 0.56.2 ABI in the README are supported. An ABI mismatch stops before installation.

The installer preserves pins/settings, refuses local source changes, verifies the bundle checksums and backend version, and disables the plugin before replacing its code. If setup fails after that point, leave it disabled and use the rollback command below. Companion applications are not installed.

## Test in order

1. **Basic launch:** open the computer icon. Settings appear centred; Escape, outside click and close button dismiss them. Repeat after a shell reload.
2. **Getting Started:** open it, search shortcuts, and compare one customized binding with your actual configuration. Open Settings and Task Manager. OmaStore is unavailable unless `omastore` is installed on PATH. Troubleshooting opens the browser.
3. **Sizing:** choose Default, Large and Extra large for dock and title bars. Try Windows/Mac/General layouts. Reopen settings and reload the shell; size and pins should persist. Theme/Off must stay respected.
4. **Show Desktop:** open two disposable windows on visible workspaces, minimise a third, then Show desktop. Restore windows returns the first two to their original workspaces and leaves the already-minimised third alone. Repeat across monitors; manually restore one window, then Restore windows must leave it where you put it.
5. **Window controls:** minimise/restore, drag, maximise, arrange left/right, Bring here and next monitor. Check a CSD app and fullscreen. Close selected window must affect only that window.
6. **Quit versus Force quit:** with disposable unsaved work, Quit app requests normal closes for windows owned by the same process; the app may show save prompts or keep running in the background. Force quit requires a second confirmation and stops that process, including its other windows. Never test force quit on important work.
7. **Lifecycle:** after restoring windows, disable/re-enable, reload, change theme, test 200% scale and unplug/reconnect a monitor. Verify your personal Hyprland configuration is preserved.

Record plugin commit (`git -C ~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop rev-parse HEAD`), `hyprctl version`, monitor/scale, step and observed result. Never report fixture tests as this live acceptance.

8. **Caps Lock:** in Familiar settings, select Normal Caps Lock and type in disposable native Wayland and XWayland apps: Caps on/off and Shift must behave normally. Check UK AltGr and your layout-switch shortcut still work, except a shortcut that itself used Caps Lock. Select Compose and test a known configured sequence. Select Use configuration and verify your original mapping returns. Repeat after Hyprland reload and login; record each separately. Per-device overrides may take precedence—test built-in and external keyboards if available. Confirm `input.lua` is byte-for-byte unchanged and only Familiar’s marked block changes in `hyprland.lua`. Changing the Familiar layout must not change this preference. A symlinked main config should be refused unchanged.

## Recovery and rollback

Restore windows even when the dock is unavailable:

```bash
~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop desktop restore
```

Run that before disabling, downgrading or removing the candidate. Also choose **Use configuration** for Caps Lock before downgrade/removal, or run `~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop caps-lock reset`. The recovery journal is kept at `${XDG_STATE_HOME:-~/.local/state}/omarchy/familiar-desktop-recovery.json`. It survives shell reloads; it never replays identities across compositor restarts. A failed restore retains remaining entries for retry. Manually moved or closed windows are skipped. Pinned windows and special workspaces are not hidden. Tiling order may differ after restoration.

To return to the published v0.0.6 after restoring windows:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tcballard/omarchy-plugin-familiar-desktop/v0.0.6/install.sh) windows
```

To remove, restore windows, then:

```bash
~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop titlebars remove
omarchy plugin remove io.github.tcballard.familiar-desktop
```

Settings, pins, badges and recovery journal are retained. Companion apps and unrelated Hyprland configuration are left in place.
