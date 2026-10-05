# Familiar v0.1.0 release preparation

Target: Monday 5 October 2026 (UK). This document prepares the release; it does not schedule publication or claim the release exists.

## Frozen scope

Core desktop only: dock and named windows; three layout presets; Automatic/Bottom/Left/Right dock placement; optional title bars; centred settings; window arrangement and recovery; Show Desktop/Restore; dock/title-bar sizes; Quit/confirmed Force Quit; active shortcuts; optional file shortcuts; explicit Caps Lock/Compose preference.

Getting Started contains System settings and Troubleshooting. The v0.2.0 app collection will expose Open for installed apps and Install only after a supported package is verified. No Paint, Notepad, Task Manager, OmaStore or Postcard installation is part of v0.1.0. These apps are not release dependencies.

## Candidate and version

The manifest, Cargo package/lockfile and all three release installers declare 0.1.0. The release executable test derives its expected version from the manifest to avoid another stale rc assertion. Historical rc.1/rc.2 notes remain historical.

Until the tag/assets exist, use the `familiar-desktop-release` artifact from the successful **Release binaries** run for this exact candidate. Extract it and run:

```bash
bash install-candidate.sh windows
```

Use `mac` for left-side controls. This installer embeds the full source SHA and version. Do not run the unexpanded template in the source tree or the future v0.1.0 download installer before assets are published. The README retains v0.0.6 as the current published install route.

## Before publication

- [ ] Merge the preparation PR after Portable checks and Release binaries pass. Record the resulting main commit and its own successful CI runs.
- [ ] Inspect the exact candidate bundle: static executable version 0.1.0, supported Hyprbars ABI, complete SHA256SUMS, release/source manifests, SPDX document, notices, installer and XPS guide.
- [ ] Run `omarchy plugin validate` on the candidate on XPS and record its output. The generic Python skill preflight is not run in this no-Python preparation; it must not be claimed as passing.
- [ ] Complete docs/XPS-TEST.md on that exact source. Record `omarchy-version`, `hyprctl version`, monitor/scale, plugin SHA and each result.
- [ ] Check fresh install, upgrade from v0.0.6, repeat install, settings/pin retention, local-change refusal, disable/re-enable, Caps reset, title-bar removal and rollback. Preserve personal files; use disposable test profiles where possible.
- [ ] Verify actual window actions, Show Desktop/Restore, focus/dismissal, keyboard behavior after reload/login, themes/scaling and available monitor coverage. State unavailable hardware coverage explicitly.
- [ ] Finish the compatibility paragraph in docs/v0.1.0.md using those results. Replace the rendered settings preview with a real screenshot when available.
- [ ] Review the existing release download trust boundary before public promotion: checksums detect corruption but are fetched beside the release; immutable provenance binding and workflow dependency pinning are not established by these checks. Do not describe this as a security audit.
- [ ] Freeze source, create an annotated v0.1.0 tag at that exact commit, and publish the release using the approved notes. Never move the tag. Observe Release binaries through asset upload and verify the downloaded published assets.
- [ ] Switch the README's primary install/update link from v0.0.6 to v0.1.0 only once those assets are present. Keep the rollback instructions.

The live checks and final provenance/publication gates are outstanding. A green portable build is a testable candidate, not a release sign-off. Do not cut the tag or publish just because the planned date has arrived.

## Evidence record

Base at preparation start: `90db20ac1919486da3fc7e55387ecfc30188bb6d` (rc.2). Both main workflows passed. This branch changes core scope presentation, version alignment, release documentation and release-version assertions. Fresh CI results belong to this PR and must not be replaced with the rc.2 results.

The prepared bundle includes this checklist and the release-note draft, with their hashes in the release manifest and SHA256SUMS. XPS acceptance uses the guide inside that same bundle.
