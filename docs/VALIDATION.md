# Familiar Desktop validation

## Automated checks

Run `tests/run` with Python 3 and Node.js. It covers the window helper, socket
timeouts and response limits, Lua quoting, widget selection, and literal command
arguments. CI additionally runs the four QtTest suites with Qt 6 offscreen and
parses all plugin QML files. QML parsing does not validate Omarchy's runtime imports.

The 28 September audit checked the portable manifest/path validator and manually
reviewed the process-launch and configuration-write paths. The advisory scanner
reports capabilities for QML processes and collected local input. Its package
manager and privilege matches are the Qt installation step in GitHub CI.
These checks are not a marketplace verification or a security certification.

The dock writes its own settings, pins and badge data. Optional title-bar setup
adds a marked, removable hook to the user's looknfeel.lua and generated
configuration under ~/.config/omarchy/familiar-titlebars; see README cleanup. It reads shell.json
for bar placement. Adding, removing or disabling dock widgets does not change
the bar layout or enable other plugins. Application commands use argument arrays,
with literal shell quoting on older host utilities. Window operations use local
Hyprland IPC; each Python socket request has a two-second deadline and an 8 MiB
response limit. Local shell QML collectors still depend on the host process and
file APIs; they are not a sandbox against a malicious same-user process.

## Preview

`preview.png` and the README image are the same unmodified screenshot supplied by
Tom Ballard on 28 September 2026, showing the General layout on Omarchy. It is
2048 × 1151. The screenshot predates the audit fixes; those fixes do not restyle
the visible layout. The precise Omarchy revision and display scale were not
recorded with the capture. The repository retains the upstream MIT notice.

## Desktop checks still to record

Record the plugin commit with `git rev-parse HEAD` and the installed Omarchy
version. Run `omarchy plugin validate .` from that checkout, then verify:

1. Fresh installation loads the dock and its bar control without QML errors.
2. General, Windows and Mac presets apply their documented positions/visibility.
3. Launch, select a named window, minimize, restore, pin, unpin and close work.
4. Dock widget selection survives off/on and shell reload, with the bar unchanged.
5. Menus dismiss correctly; keyboard reveal, workspaces, two monitors and 200%
   scaling work; light/dark themes remain readable.
6. Disabling and removing the plugin remove its surfaces while other bar widgets
   remain available. Only the documented plugin-owned data is left behind.

The audit environment has no live Omarchy session. CI success does not mark these
desktop checks as passed. Marketplace submission also needs the owner's code
and preview permission attestation and the marketplace's exact-commit review.

## Window-control integration (30 September)

Portable tests exercise setup/disable idempotence, ownership collisions, stale
instance teardown and late apply, reload/configuration/ABI-load failures, exact
window-address actions, theme-colour validation and class escaping. The shell
adapter has an operation watchdog and one queued follow-up when settings change.
It never installs dependencies. The terminal installer delegates dependency
builds/version selection to hyprpm, then probes load and Lua button support.

Record on-device evidence before release: click close/minimise/maximise on both
focused and unfocused windows; restore each from the dock; drag tiled/floating
windows; double-click title bars; switch themes and styles; test grouped and
fullscreen windows, app exclusions, two monitors and mixed scales. Disable the
dock/plugin, restart/hot-reload the shell, remove the integration, and confirm
personal looknfeel.lua overrides and unrelated compositor plugins survive.
An abrupt shell crash can defer cleanup; use the documented remove command.

Source contracts inspected: Omarchy quattro's plugin registry/bar injection and
Lua config hooks; Hyprland's hl.plugin.load, window dispatchers and config reload;
Hyprbars' Lua add_button, configuration options and button layout. These source
checks and portable mocks do not establish compatibility with the user's exact
Hyprland build. The existing preview predates this feature.
