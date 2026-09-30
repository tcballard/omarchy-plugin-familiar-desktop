# Familiar Desktop validation

## Rust migration (30 September 2026)

The backend is one Rust executable, `bin/familiar-desktop`. Python helpers,
inline Python badge writes and Python tests are removed. QML remains hosted
inside Omarchy's shell. No second shell is launched. The explicit terminal
`build.sh` compiles locked source and atomically installs the executable;
`install.sh` includes this build. The hosted runtime never runs Cargo or hyprpm.
Rebuild after a development checkout update. CI uploads an x86_64 Linux binary.

The source before migration is `d5004d365d4844db99edc43db4d2571cb2ae3e3d`.
Source contracts were inspected against Omarchy quattro
`8b4eae66da2938ba9559f103b18dbf85cdf28a70`. This environment has Qt offscreen but
no Omarchy session or Quickshell runtime imports. It also rejects Unix socket
creation with EPERM. Host checks are unrun, never counted as passing.

## Automated evidence

The Rust suite contains 60 tests: dock selectors, terminal/PWA matching,
minimise/restore and sibling focus, icon precedence, exact window addresses,
setup/disable/remove, ownership and stale sessions, theme policy, Lua quoting,
reload/ABI failures, atomic badges, bounded files and command output, deadlines
and descendant cleanup. Three tests execute the built CLI with a fictional
hyprctl; those are integration fixtures, not a real compositor.

Locally, 57 Rust tests pass. The three real Unix socket tests are blocked by
EPERM; they remain enabled in `tests/run` and CI. They cover successful response,
oversized response and stalled input. Local reproduction of the supported subset:

```bash
cargo test --manifest-path backend/Cargo.toml --locked -- \
  --skip socket_normal_response_is_collected \
  --skip oversized_socket_response_is_rejected \
  --skip stalled_socket_has_whole_operation_deadline
```

QtTest passes 117 tests, including the actual TitlebarController with narrow
Quickshell stubs that never execute commands: overlapping refreshes, stale
completion, disable during apply, failure/recovery, watchdog and conditional
teardown. Node exercises both real QML settings readers/writers and literal
command arguments. Product QML parses; generated Mac/Windows Lua parses.

```bash
# On an environment allowing Unix sockets, these run every Rust test.
tests/run
cargo fmt --manifest-path backend/Cargo.toml -- --check
cargo clippy --manifest-path backend/Cargo.toml --all-targets --locked -- -D warnings
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qmltestrunner -input tests -import tests/imports -o -,txt
bash -n build.sh install.sh
git diff --check
./build.sh
bin/familiar-desktop --version
```

## Plugin skill audit

Applied plugin design, bar-widget, service/IPC, QML patterns, debug, test and
release-preflight skills. Run the loaded plugin-test skill's portable validator
normally and with `--json --security --publish --strict`. Advisory capabilities
for local processes, collectors, terminal installation and CI's package install
require manual review; static validation is not security certification or
marketplace approval. The checked-out Omarchy validator provides source-contract
validation, not verification against an installed host.

The release helper expects named sibling skill directories, but this environment
installs skills under opaque names. Its read-only preflight can run by redirecting
only `validator_path()` to the actual loaded validator. No validation rules or
skill files are modified. The desktop and preview gates below remain separate.

Runtime subprocesses bound stdout and stderr independently to 1 MiB while
receiving, with an eight-second whole-operation deadline and process-group
cleanup before reaping. Direct socket operations cap responses at 8 MiB with a
two-second whole-operation deadline, including connect. Settings and theme reads
cap the opened regular file at 256 KiB; active theme symlinks are supported.
Theme FileViews watch without preloading. State changes hold a bounded file lock.
Generated Lua cannot accept theme-supplied commands; dispatch addresses are
validated. Badge writes are atomic and capped at 256 KiB.

## Files and removal

The dock writes its own settings, pins and badges. It reads shell.json for bar
placement, without replacing the bar layout. Title-bar setup adds a marked,
removable looknfeel.lua block and owned generated configuration. Run the documented
`bin/familiar-desktop titlebars remove` before removing the plugin. Hyprbars,
preferences and badge data are deliberately retained; removing the plugin removes
its locally built binary too. An abrupt shell crash can defer title-bar cleanup.
Inherited QML file collectors remain subject to host APIs' limits and are not a
sandbox against a malicious same-user process.

## Live checks still to record

Record the exact plugin SHA and installed Omarchy/Hyprland versions. Verify:

1. Fresh Git install, terminal build, discovery, enablement and both entry points.
2. Dock launch, minimise, restore, explicit window selection and sibling focus.
3. Title-bar close/minimise/maximise on focused and unfocused windows; dragging
   and double-click; CSD exclusions, grouped/fullscreen windows and mixed scales.
4. Theme policy edits and switches, malformed policy recovery through Off,
   manual overrides and settings persistence across restart/reload.
5. Horizontal/vertical bars, two monitors, workspaces and 200% scale.
6. Fast-forward update plus rebuild, disable/re-enable, removal and preservation
   of personal Hyprland config and unrelated compositor plugins.

## Preview provenance

`preview.png` and the README image are the same unmodified screenshot supplied
by Tom Ballard on 28 September 2026: General layout on Omarchy, 2048 × 1151.
The precise Omarchy revision and scale were not recorded. This screenshot
predates title bars and the Rust migration. Version 0.0.1 is an early preview. A current on-device capture and the live
checks above remain outstanding before a desktop-verified release or marketplace submission.
