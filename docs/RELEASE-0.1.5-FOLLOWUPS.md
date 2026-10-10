# v0.1.5 issue follow-ups

Prepared text only. Post after final v0.1.5 publication and the stated verification, with Tom's authorization to send issue messages. Replace any verification claim if the final evidence differs. [PR #81](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/81) and [release preparation](RELEASE-0.1.5.md) contain the candidate record.

## #82 — folder-handler lifetime

Included in Familiar v0.1.5: Home/Downloads now wait only for `gio`, with detached output streams. Opener timeout cleanup leaves the launched file manager running. The long-lived non-D-Bus handler regression passed; Tom reported the combined development candidate working on the XPS. Thanks @dmalmq for the detailed reproduction and suggested fix. Release: https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/tag/v0.1.5

## #83 — Home glyph

Included in Familiar v0.1.5: Home uses the matching home-outline glyph U+F06A1 at the existing shortcut size. The icon regression passed and Tom reported the combined development candidate working on the XPS. Thanks @dmalmq for reporting the mismatch. Release: https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/tag/v0.1.5

## #76 — gestures and Command shortcuts

Included in Familiar v0.1.5: generated gesture callbacks dispatch through `hl.dispatch`; Command aliases send balanced key-down/key-up events. Generated callbacks passed against the supported native compositor, and old-file replacement fixtures passed. Already-enabled preferences from older installs should be reset/reapplied in Familiar; personal edits remain protected. Physical gesture/keyboard-specific results were not separately reported. Thanks @gfisek for the API findings and working examples. Release: https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/tag/v0.1.5

## #78 — Qt 6.12 palette

Included in Familiar v0.1.5: shipped palette references and signal subscriptions use `Commons.Color`. Native smoke passed on Qt 6.11.2 / Quickshell 0.3.1 and Qt 6.12.0 / Quickshell 0.3.2 with the pinned patched Core. Updating Familiar alone does not repair an unpatched Core or mismatched runtime. The XPS report did not identify its Qt version. Release: https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/tag/v0.1.5

## #67 — browser titlebars

Included in Familiar v0.1.5: Chrome/Chromium skip the extra Familiar titlebar by default. A persisted opt-out enables Familiar controls again; personal app exclusions remain separate. The policy/controller and settings-render regressions passed, and Tom reported the combined development candidate working on the XPS. Thanks @maddada for the report. Release: https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/tag/v0.1.5

## #74 — official backend migration

Keep open. v0.1.5 retains the existing coexistence guard; it does not migrate to the official titlebar backend. Backend provenance, shared configuration ownership and rendering/action parity still require a verified integration contract. The browser-titlebar fix does not resolve this migration. Current audit: https://github.com/tcballard/omarchy-plugin-familiar-desktop/blob/v0.1.5/docs/TITLEBAR-MIGRATION.md

## #46 — future Dock workflows

Keep the eighteen child enhancements #48–#65 open. v0.1.5 improves maintainability and fixes reported defects, including plugin panel icons; it does not complete those distinct workflows. General, Windows and Mac remain supported starting layouts. The Mac-only proposal and further decomposition are deferred.
