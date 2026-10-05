# Familiar v0.1.0 final candidate — XPS acceptance

This is the v0.1.0 desktop candidate. Automated tests use fixtures; this checklist records actual Omarchy/Hyprland behavior. The curated app collection and Open/Install shortcuts are deferred to v0.2.0. This candidate does not include a Windows taskbar redesign or macOS window previews.

## Install

Download and extract the `familiar-desktop-release` ZIP from the candidate PR's successful **Release binaries** workflow. From that extracted folder:

```bash
bash install-candidate.sh windows
```

After installing, run `omarchy restart shell` to load the new QML and title-bar library.

Use `mac` for left-side controls. This installs the exact commit embedded in the bundle, with a static prebuilt Rust helper and the prebuilt Hyprbars library. No Rust, Clippy, compiler, Hyprpm or Hyprland checkout is needed. Linux x86_64 and the Hyprland 0.56.2 ABI in the README are supported. An ABI mismatch stops before installation.

The installer preserves pins/settings, refuses local source changes, verifies the bundle checksums and backend version, and disables the plugin before replacing its code. If setup fails after that point, leave it disabled and use the rollback command below. Companion applications are not installed.

## Test in order

1. **Basic launch:** open the computer icon. Settings appear centred; Escape, outside click and close button dismiss them. Repeat after a shell reload.
2. **Getting Started:** open it, search shortcuts, and compare one customized binding with your actual configuration. Open System settings and Troubleshooting. There must be no OmaStore, Task Manager, Paint, Notepad or app-install buttons in Getting Started; existing apps remain launchable through the ordinary dock.
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

## Dock selection and visual controls retest

- In **Dock → Dock position**, choose Bottom, Left and Right. Check vertical icons, file shortcuts, widgets, app menus, folder menus and hover hints at each edge. Open a menu before moving the dock: it must dismiss. Check reserve-space and overlay modes, plus hover reveal on the new edge (the old edge must stop responding).
- Reopen settings, change General/Windows/Mac layout, then restart the shell: the explicit position must persist. Select Automatic to restore preset placement. Put Omarchy’s bar on the requested edge: the dock must move opposite with an explanation in settings, then return to your requested edge when the bar moves away. Check both monitors and 200% scale where available.
- Add Apps, Clock, Audio and two plugin widgets. All switches must stay selected; close/reopen the picker and restart the shell, then check them again. Remove only Audio and confirm every other selection remains. Disable/re-enable dock widgets and confirm the selection survives.
- Switch between a light and dark theme. The dock background and widget text follow the bar palette; title-bar background/text follow popup tokens unless the theme explicitly overrides them.
- Mac controls: circular traffic lights, crisp dark marks on hover, expand arrows instead of a plus. Windows controls: rounded-square buttons with close/minimise/maximise paths. Verify clicks at 100%, 150% and 200% scale, including moving between differently scaled monitors.
- Apps that draw their own header can still show duplicate controls. The existing window-class exclusion remains available; automatic detection is not part of this fix.
