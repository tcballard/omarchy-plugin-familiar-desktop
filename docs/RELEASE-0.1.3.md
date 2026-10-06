# v0.1.3 release preparation

Fixes the notification badge privacy finding in marketplace issue #10184,
comment 6024396474. This is a new runtime change, not covered by the earlier
v0.1.1-rc.4 XPS acceptance.

Portable validation includes notification identity/transport regression tests,
Rust CLI stdin and permissions checks, malformed/oversized input preservation,
formatting and clippy. CI requires a real process-table assertion; the local
sandbox virtualizes child PIDs and cannot perform that assertion.

Before publication, require green portable and release builds, matching committed
backend digest, and a live Omarchy notification/save/reload check. Ship v0.1.3 QML
and backend together. Do not overwrite v0.1.2 assets. Marketplace approval is not
claimed. See NOTIFICATION-PRIVACY.md for scope and compatibility.
