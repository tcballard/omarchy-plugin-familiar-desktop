# Code map and ownership

Read [WORKFLOW.md](WORKFLOW.md) first. Start each maintenance change on a feature
branch. Run `tests/check` before preparing a source-bound development build.

## Where to make a change

| Behaviour | Owner and entry point | Focused coverage |
| --- | --- | --- |
| Durable dock and titlebar preferences | `components/SettingsStore.qml`, `components/SettingsSchema.js`; service aliases in `DockPanel.qml` | `tst_SettingsStore.qml`, `test_widget_config.cjs`, `test_dock_opacity.cjs` |
| Settings navigation and controls | `components/SettingsContent.qml`, `SettingsFrame.qml`; `BarWidget.qml` opens the modal and reads the service | `test_settings_layout.cjs`, `tst_SettingsFrame.qml` |
| Dock lifecycle, monitors and visibility | `DockPanel.qml`, `DockSettings.js`, `DockPosition.js`, `components/DockVisibility.qml` | `test_dock_position.cjs`, `tst_DockVisibility.qml`, desktop smoke |
| App matching and window history | `DockModel.js` facade → `DockMatcher.js`; curated data in `AppCatalog.js` | `test_window_history.cjs`, `test_app_identity.cjs` |
| Notification and title badge grouping | `AppIdentity.js`, `components/NotificationTracker.qml` | `test_notification_counts.cjs`, `test_notification_privacy.cjs` |
| Runtime icon sources | `IconResolver.js`, using candidates and disk cache supplied by `DockModel.js` | `test_app_identity.cjs` |
| Pins, folders and launching | `DockPinned.js`, `DockAutoName.js`, `DockLauncher.js`; menu/popup QML | Node model checks, desktop smoke |
| Left/right hosted widgets | `components/DockWidgetSlot.qml`, `HostedWidgets.js`, `DockWidgets.js`; service action adapter | `test_widget_anchor.cjs`, `tst_DockWidgetSlot.qml` |
| Ordinary preference requests | `components/BackendRequest.qml`; small Caps Lock, Gestures, InputPreference, WindowMode and Taskbar controllers | Corresponding QtTest controller tests |
| Native configuration changes | Feature modules in `backend/src`; shared `config_file::apply_generated` transaction | `backend/tests/config_transactions.rs` and feature integration tests |
| Titlebar reconciliation | `components/TitlebarController.qml`, `backend/src/titlebars.rs`, `hyprbars/` | Titlebar backend/QtTest tests; exact-build desktop acceptance |
| Setup, downloads and repair | `components/SetupController.qml`, `setup-in-app.sh`, installer scripts | Setup QtTest, installer Node fixtures |
| Taskbar shell-layout snapshot | `backend/src/taskbar.rs`, `components/TaskbarApps.qml` | Taskbar backend/QtTest tests and bar placement fixtures |
| Development/release packaging | `scripts/prepare-dev-bundle.cjs`, `scripts/install-dev.sh`, workflows | Development/release packaging and rollback fixtures |

Paths in this table are relative to the repository (tests are under `tests/`
unless a backend path is given). Follow the facade for model callers; importing a
private matching implementation into a view creates a second API to maintain.

## State boundaries

`DockPanel.qml` is the hosted service and the only runtime owner of
`~/.config/omarchy/familiar-desktop-settings.json`. Its SettingsStore watches the
file, validates known fields and preserves unknown fields. Views bind to service
properties and call service setters; they must not read or write a second copy.
Malformed external settings are preserved and surfaced as an error.

Pins have a separate `familiar-desktop-pinned.json` file. Window focus history,
hover/drag state, widget instances and icon lookup caches are session state.
The matcher library's disk icons and CLI hints are updated by the service and
shared through `DockModel`; settings views do not mutate them. Notification event
counts and urgency persist, while title-derived unread counts are a live snapshot.
Private notification text never belongs in a command argument.

`AppIdentity.toCanonical` creates a grouping/badge key, not a launch identifier.
Keep exact desktop/PWA IDs for launching and pins. `AppCatalog` contains static
metadata; changes to an alias should have a grouping regression test. Icon lookup
uses the same candidate priority everywhere, with an explicit friendly fallback
for app tiles and a generic fallback for previews.

## Backend boundaries

QML requests an explicit operation; Rust owns native configuration edits.
Ordinary controllers declare allowed choices, expected response modes and
arguments on BackendRequest. Invalid input, overlapping requests and malformed
responses fail without optimistic success. Setup's streaming output and the
revision/ownership lifecycle of titlebar reconciliation remain specialized.

Each native preference module validates its owned hook, migration and generated
Lua, and takes its feature lock. It supplies expected/new bytes to
`config_file::apply_generated`, which writes the owned generated file, replaces
the main config with a backup, reloads, checks configuration errors and runs any
feature verification. Failure restores the previous bytes only if they still
match; external edits stop rollback. Reset removes the owned file after a
successful reload. Taskbar and titlebar transactions retain their distinct
ownership and restoration rules.

## Validation and extension

Use `tests/check` as the portable entry point. Qt tests use inert Quickshell
imports; they do not prove compositor behaviour. Installer fixtures use temporary
homes and fake desktops. Add behaviour tests at exported JS functions or component
APIs; avoid extracting functions using nearby comments or layout text.

For a preference: extend SettingsSchema/SettingsStore, bind the settings view to
the service, and test restore/save/defaults. For a native operation: keep parsing
and Lua in its feature module and use the shared transaction. For a hosted widget:
use DockWidgetSlot on both sides and supply the narrow action adapter.

A passing portable suite is readiness for desktop testing. Follow
[DEVELOPMENT.md](DEVELOPMENT.md), [DESKTOP-SMOKE.md](DESKTOP-SMOKE.md) and
[DOCK-PREVIEWS.md](DOCK-PREVIEWS.md) for source-bound builds, real lifecycle checks
and rollback. The official titlebar migration has separate unresolved contracts
in [TITLEBAR-MIGRATION.md](TITLEBAR-MIGRATION.md).
