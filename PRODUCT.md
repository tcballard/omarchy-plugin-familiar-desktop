# Familiar Desktop

Familiar gives Omarchy users visible app and window controls, with General,
Windows and Mac starting layouts. It runs as a hosted service and bar widget
inside Omarchy's Quickshell process under `io.github.tcballard.familiar-desktop`.

## Current scope

- App dock, optional Windows taskbar, pins and folders, window previews, app and
  window actions, badge counts, file shortcuts and hosted Omarchy widgets.
- Shared settings with dock size, placement, visibility, background opacity,
  widget layout, titlebar style and exclusions, and shortcut-label preferences.
- Optional native preferences for Caps Lock, border resizing, Command editing
  shortcuts, new-window floating/tiling and trackpad gestures. Each is explicit
  and reversible; personal configuration is preserved.
- Getting Started, system tools, window arrangement and Show Desktop/Restore.
- In-app setup and repair plus source-bound development installation and rollback.
  Network downloads belong to explicit setup/install/repair actions.
- Optional bundled window controls for supported existing installations. The
  official titlebar-package transition remains tracked separately in
  [TITLEBAR-MIGRATION.md](docs/TITLEBAR-MIGRATION.md).

Settings and pins belong to Familiar. Native preferences own exact guarded
includes and generated Lua, with backups and verification. Taskbar selection is
an explicit exception: its Rust transaction changes the selected shell layout
and keeps a reversible snapshot. Ordinary dock widgets leave bar layout alone.
No hosted runtime invokes Cargo, launches a second shell, or silently installs
companion apps or packages.

The planned curated app front door remains future scope. Historical prototypes,
release plans and dated evidence are in the [archived product notes](docs/history/PRODUCT-2026-10-10.md)
and the individual release documents; they do not establish acceptance of a new
build.

## Developing Familiar

Start with [ARCHITECTURE.md](docs/ARCHITECTURE.md) for the feature-to-file map and
ownership boundaries. [DEVELOPMENT.md](docs/DEVELOPMENT.md) explains local checks,
exact-source development builds and rollback. [WORKFLOW.md](docs/WORKFLOW.md)
requires green current CI, Tom's acceptance of the exact build on the XPS and
merge authorization. Release authorization is separate.
