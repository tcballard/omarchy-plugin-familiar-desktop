# Familiar Desktop: product and development record

## Intended user

People moving to Omarchy from Windows or macOS need a visible, familiar route
to apps and windows. The General preset is for people who simply prefer a
mouse-friendly desktop, regardless of their previous OS. The first release
should answer: what is open, which window is mine, and how do I get back to it?

## Ownership and architecture

- ID: `io.github.tcballard.familiar-desktop`.
- Kinds: `service` (`DockPanel.qml`) and `bar-widget` (`BarWidget.qml`).
- Process: hosted in the existing Omarchy Quickshell process. No second shell.
- Settings: plugin-owned JSON in `~/.config/omarchy/`; pins are separate and
  shared by all three presets. Dock widgets leave the bar layout unchanged;
  `~/.config/omarchy/shell.json` is read-only.
  The hosted runtime does not modify themes, global bar position or shortcuts,
  or install packages. Optional title-bar dependency setup is an explicit
  terminal operation, described below.
- External operations: the shared Rust `bin/familiar-desktop` backend uses
  `hyprctl` for window activation and minimization, title-bar setup, policy and actions; icon/CLI scans
  use local desktop files. No network calls or privileged commands are added.
- IPC: existing dock methods plus `setProfile general|windows|mac`.
- Disable/remove: hosted surfaces disappear; plugin settings and pins persist.

## Shipped in this prototype

The forked dock has its own ID and config paths. Right-click gives an explicit
app action menu with named windows and direct actions. A bar settings control
applies three starting presets; manual settings can then be adjusted. The Mac
and Windows names denote layout starting points, not pixel-perfect emulation.

## Next milestones

1. Verify on an Omarchy XPS. Fix any QML loading, focus, layer, menu dismissal,
   and multi-monitor defects observed there. Add keyboard navigation to the
   app menu and avoid opening a second context card across displays.
2. Improve discovery: use app and folder menus for pin, reorder, edit, and
   removal without requiring long-press gestures; make running state clearer.
3. Build a true Windows taskbar presentation from the shared app model, and a
   Mac dock presentation with previews. Keep General independently useful.
4. Add a reversible, opt-in setup experience for companion theme/apps once
   those projects have stable package identities. Do not make a shell plugin
   perform installation or privilege changes.
5. Test 200% scale, light/dark themes, tiled,
   floating, fullscreen, monitor hotplug, reload, disable, and removal before
   opening a release or marketplace submission.

## Current evidence

Portable manifest/path validation and unit tests pass. An on-device screenshot
of the General layout is in the README. The audit environment has no Omarchy
session or Quickshell imports, so lifecycle behavior is unverified
here. The public GitHub repository exists; no release has been created.


## Integrated window controls

Familiar remains one Omarchy plugin. Optional Hyprbars decorations provide a
visible window title and mouse controls, Mac/Windows placement, dragging and
double-click maximise. Minimise and restore share the existing dock helper.
Controls inherit shell background/text colours and fonts. Theme mode reads
`familiar-desktop.json` from the active theme for enablement, placement, geometry,
button colours and exclusions; explicit Off/Mac/Windows choices take precedence.
Theme switches and local policy edits queue serialized refreshes. Invalid policy
fails closed. The Familiar theme provides Windows defaults for desktop tuning.
A terminal installer owns the one-time dependency/config setup; runtime QML
only reconciles local configuration. One-time dependency setup remains required.
Existing explicit choices are preserved; other installations default to Theme.
Title bars require
live Hyprland verification before release, especially grouping, CSD apps,
fullscreen, mixed scales, upgrade and removal behaviour.
