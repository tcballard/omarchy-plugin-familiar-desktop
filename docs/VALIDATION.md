# Familiar Desktop validation

## Automated checks

Run `tests/run` with Python 3 and Node.js. It covers the window helper, socket
timeouts and response limits, Lua quoting, widget selection, and literal command
arguments. CI additionally runs the five QtTest suites with Qt 6 offscreen and
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

Theme-policy checks cover enable/disable on theme switches, manual precedence,
shared shell font/palette fallbacks, exclusion merging, migration of explicit
preferences, rejected schema/geometry/unsafe values and recovery through Off.
Both actual QML settings handlers preserve the new mode across save/reload.
Local validation passes 55 Python tests, 117 Qt tests, Node handler tests, QML
parsing, generated Lua syntax and the portable plugin validator.
On the desktop, also switch between Familiar and a theme without this policy,
edit its sizing/font/colour options, and confirm Off and manual styles persist.

## Plugin-skills audit (30 September)

Reviewed the title-bar change using plugin design, bar-widget, service/IPC,
QML patterns, debug, test and release-preflight skills. Source before the audit:
`07e140c4bb1d4a00ba59231fc30f107abed6a803`; the audit commit adds the fixes and
tests described below. Read-only source contracts were checked against the
local Omarchy quattro checkout at
`8b4eae66da2938ba9559f103b18dbf85cdf28a70`.

The portable skill validator reports no schema errors, quality warnings or
advisory security findings. It reports review-required capabilities for local
processes, file/stdio collection, the explicit terminal installer and CI's Qt
package installation. These are manually reviewed capabilities, not a security
certification or marketplace approval. Existing dock settings, notification and
other inherited file collectors remain subject to the host APIs' limits.

The audit replaced post-completion temporary-file size checks with bounded pipe
reads and a whole-operation deadline. Stdout and stderr each cap at 1 MiB;
failures stop and reap the original child/session before its identity can be
reused. Settings/theme reads now cap the opened regular file at 256 KiB instead
of checking a pathname and then reading without a limit. Theme FileViews only
watch changes, with preloading disabled; the bounded Python helper owns reads.

New tests execute real flooding and stalled subprocesses, verify descendant
cleanup, reject oversized files/FIFOs and preserve supported theme symlinks.
QtTest loads the actual TitlebarController with narrow Quickshell stubs that
never execute commands. It verifies serialization, stale-result rejection,
disable during apply, failure/retry, the watchdog and conditional teardown.

Reproduction commands from this checkout:

```bash
git rev-parse HEAD
git -C ../omarchy rev-parse HEAD
tests/run
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qmltestrunner -input tests -import tests/imports -o -,txt
bash -n install.sh
git diff --check
```

The loaded plugin-test skill's `scripts/validate_plugin.py` runs both normally
and with `--json --security --publish --strict`. Omarchy's checked-out
`bin/omarchy-plugin-validate .` also passes; this is source-contract validation,
not validation against an installed host. All product QML parses with qmlformat.
Generated Mac and Windows Lua parses with Lua 5.4's luac.

The debug doctor confirms Omarchy, omarchy-shell and Quickshell are unavailable.
The release helper initially cannot locate its sibling validator because this
environment installs skills under opaque directory names. Running the same
helper with only `validator_path()` redirected to the actual loaded test skill
allows the preflight to run. This does not alter validation rules or skill files.
Static preflight is separate from the unrun release gates: live discovery,
enable/disable/reload, horizontal/vertical bars, multiple monitors, fresh Git
installation/update/removal and a current title-bar preview. No tag or release
is created by this audit.
