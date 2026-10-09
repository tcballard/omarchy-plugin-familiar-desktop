# v0.1.4 release acceptance

Prepared and accepted at Tom’s request on 9 October 2026 on `v0.1.3-hotfix`, PR #77. This combines the desktop hotfix and Matteo Murgida’s PR #80, cherry-picked with original authorship, plus the review corrections recorded in [PR80-REVIEW.md](PR80-REVIEW.md).

Tom accepted installed source `13288082d95ed451c0603a0fb487f388d72e9318` after testing the final compact menu and combined hotfix: “everything now passes my testing so lets ship”. This explicitly authorizes merge and final v0.1.4 publication. The installed clean checkout and development receipt identify that exact source; both installed binary digests match the receipt and reviewed pins. No separate step-by-step owner report is inferred from this overall acceptance.

Environment: Dell XPS 9320, Omarchy 4.0.4 (local revision `4ee6d4eeea176b0bf4014ce8b82a148a9433efff`), Hyprland 0.56.2-2, Quickshell 0.3.1-1; the recorded eDP-1 monitor is 1920×1200 at scale 1.

Accepted development artifact: `familiar-dev-13288082d95ed451c0603a0fb487f388d72e9318-37982018804-1`, [desktop smoke run 37982018804](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/37982018804), attempt 1. Both pinned Omarchy revisions passed. [Release binaries run 37982018546](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/37982018546) and current portable checks passed. Backend SHA256: `5e3f64dae3d921ea1db461888bec96dc3b5b6e5925a014028c34dc3fb5b7b59b`; Hyprbars SHA256: `7eb0f6162b7342346a9a7c309d067d1634d79dfd71a5ec3c0132d46635b3dc06`.

The accepted artifact's `SHA256SUMS` manifest has SHA256 `b8602a5db2c75efec6ea5f198c56c249a62e3b0b51aec7d17bfb5b084e282eb4`; retain the original downloaded bundle with the receipt.

The XPS rollback snapshot is `/home/tcballard/.local/state/familiar-desktop/dev-snapshots/build-WbXNMEgr`. Personal settings, pins, receipts and recovery snapshots remain intact. Release documentation and acknowledgements are the only changes after desktop acceptance; production QML, scripts, manifest, backend and binary pins must remain byte-identical through merge. Require green merged-main checks and matching verified main artifacts before publication. The v0.1.3 tag remains unchanged.

Publish through the explicitly dispatched green-main workflow, then verify anonymous onboarding URLs and fresh setup/retry before treating #79 as publicly resolved. Existing v0.1.3 checkouts must update to v0.1.4. This release does not republish v0.1.3 or include #74, #76 or #78. Follow [HOTFIX-SMOKE.md](HOTFIX-SMOKE.md) and [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md).
