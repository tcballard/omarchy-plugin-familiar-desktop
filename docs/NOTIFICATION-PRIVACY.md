# Notification badge privacy fix

Addresses HANCORE-linux's report on marketplace issue #10184, comment 6024396474.

Notification summaries are no longer used as badge identities, including the
fallback for notifications without application metadata. Browser notifications
badge the browser; Familiar no longer guesses a web app from message text.
Window titles can supply unread counts, but no longer supply persisted keys when
an application ID is absent.

The QML tracker sends badge JSON through a process stdin pipe to
`familiar-desktop badges save --stdin`. No JSON is placed in process arguments,
including state loaded from older versions. The backend bounds reads to 256 KiB
plus one byte for limit detection and retains atomic mode-0600 state writes.
Invalid or oversized input leaves the previous state intact. The old JSON-in-argv
CLI form is rejected. Existing private badge files are not deleted or rewritten
merely by loading them; old keys may remain in that private state.

## Release requirement

Ship the updated QML and rebuilt backend together in a new release, with the
backend digest committed to `release-binaries.sha256`. The v0.1.2 release and
its existing assets are unchanged and remain affected. Do not pair this QML
with the old backend: the old backend does not implement `--stdin`. Update
release metadata and pins before distributing this change through native setup.

## Verification

`node tests/test_notification_privacy.cjs` executes the notification handlers and
save/start handlers with a private message fixture and legacy sensitive state.
Rust CLI coverage checks actual `/proc/<pid>/cmdline`, stdin persistence, file
permissions and rejection of the old invocation. `badge_privacy` covers malformed
and oversized pipe input without replacing existing state.

These portable checks do not replace a live Quickshell save/reload check on
Omarchy. They do not claim protection from another process running as the same
user or from root.
