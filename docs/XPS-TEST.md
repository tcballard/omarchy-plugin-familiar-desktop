# Familiar v0.1.1 candidate — XPS acceptance

This is the v0.1.1 desktop candidate. First complete the new preference, pointer focus, upgrade and repair checks in [RELEASE-0.1.1.md](RELEASE-0.1.1.md), then run the core checks below. Automated tests use fixtures; this checklist records actual Omarchy/Hyprland behavior. The curated app collection and Open/Install shortcuts are deferred to v0.2.0. This candidate does not include a Windows taskbar redesign or macOS window previews.

## Install

Use this installation path only when the candidate PR's successful **Release binaries** workflow provides a source-pin-verified `familiar-desktop-release` ZIP. A `familiar-desktop-packaging-validation` artifact is validation-only: its unreleased binaries differ from committed pins, it contains no installers, and it is not suitable for this acceptance installation. Green CI alone does not approve a candidate for installation or publication.

Download and extract the `familiar-desktop-release` ZIP. From that extracted folder:

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
6. **Compact app menu:** check Go to / restore, Bring here, New Window, Pin/Unpin and Minimise. Single-window apps skip the window list; multiple-window apps show three rows with scrolling for more. Apps with no windows show only New Window and Pin/Unpin. Verify window selection and actions in both Mac and Windows.
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

To remove this candidate:

```bash
bash ~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/uninstall.sh
```

Settings, pins, badges and recovery journal are retained. Companion apps and unrelated Hyprland configuration are left in place.

## Dock selection and visual controls retest

- In **Dock → Dock position**, choose Bottom, Left and Right. Check vertical icons, file shortcuts, widgets, app menus, folder menus and hover hints at each edge. Open a menu before moving the dock: it must dismiss. Check reserve-space and overlay modes, plus hover reveal on the new edge (the old edge must stop responding).
- Reopen settings, change General/Windows/Mac layout, then restart the shell: the explicit position must persist. Select Automatic to restore preset placement. Put Omarchy’s bar on the requested edge: the dock must move opposite with an explanation in settings, then return to your requested edge when the bar moves away. Check both monitors and 200% scale where available.
- Add Apps, Clock, Audio and two plugin widgets. All switches must stay selected; close/reopen the picker and restart the shell, then check them again. Remove only Audio and confirm every other selection remains. Disable/re-enable dock widgets and confirm the selection survives.
- Switch between a light and dark theme. The dock background and widget text follow the bar palette; title-bar background/text follow popup tokens unless the theme explicitly overrides them.
- Mac controls: circular traffic lights, crisp dark marks on hover, expand arrows instead of a plus. Windows controls: rounded-square buttons with close/minimise/maximise paths. Verify clicks at 100%, 150% and 200% scale, including moving between differently scaled monitors.
- Apps that draw their own header can still show duplicate controls. The existing window-class exclusion remains available; automatic detection is not part of this fix.

## Minimise/restore regression (#34)

- On an otherwise empty workspace with no special workspace open, open one disposable window and minimise it from the title bar. It must disappear without a workspace round-trip. `hyprctl -j monitors` must still show the original regular workspace and must not show `special:minimized` as active.
- Restore it from the dock, then minimise it from the dock's app menu. It must disappear again; restore must bring it back and focus it.
- Open two disposable apps on the same workspace and minimise them in sequence. Minimising the second must not reveal the first. Restore each separately and confirm the other stays minimised until selected. Repeat with two windows of the same app.

Inspect actual window visibility as well as workspace state. Hyprland's client `visible` field does not include workspace visibility, so it is not sufficient proof that a minimised window is on screen.

## Clean rollback acceptance

Complete [ROLLBACK.md](ROLLBACK.md) before release: separate Caps Lock file, byte-preserving fresh title-bar install/remove, preservation of subsequent personal edits, edited-hook refusal, failed reload stopping deletion, and actual Hyprbars unload. Generic plugin deletion is not this cleanup path.

## Input follow-up after rc.1

- Change Input → shortcut labels, reopen settings and refresh the shell. Verify
  Command/Option/Control persist, both “Super” and “Command” find the same shortcut,
  and actual keybindings and copied Lua are unchanged.
- Select workspace, desktop and combined gestures explicitly. Test three fingers
  left/right and four down/up, including fullscreen clients and multiple monitors.
  Check that a deliberate existing gesture conflict causes rollback and no config
  error remains; desktop-only must work when workspace gestures are already owned.
- Use configuration, disable/re-enable, and uninstall. Verify personal config is
  preserved and owned preferences are removed on reset/uninstall. As with the
  keyboard/window preferences, disabling the shell plugin alone does not remove
  a compositor preference; reset it first if you want it off.
- Two-finger tap a dock item with system tap-to-click configured; it must open the
  named-window menu. Smooth scroll an app with multiple windows and check motion
  threshold, both axes, direction reversal and ordinary mouse-wheel behaviour.

These are live acceptance checks, not claimed results from portable fixtures.
