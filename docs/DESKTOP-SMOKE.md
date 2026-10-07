# Disposable desktop regression checks

`Desktop smoke` builds the exact PR head, then runs a real Hyprland compositor
and the pinned Omarchy Quattro shell in an Arch container on a disposable
GitHub-hosted Ubuntu VM. Weston provides the parent Wayland display and Mesa
provides software rendering. No personal desktop, hardware devices, secrets,
host display sockets or privileged container are required.

The test fails if any prerequisite, desktop startup, assertion or timeout fails.
It never substitutes the QtTest mocks or treats an unavailable desktop as a pass.
It is an additional CI check; the existing portable tests remain independent.

## Scope

- Bootstrap a pinned v0.1.2 fixture using its real binary-download/setup helpers.
- Install the exact candidate with the production development installer.
- Require real shell and Familiar IPC responses.
- Launch two real foot windows; verify their compositor identities.
- Activate, minimise and restore an exact window, checking actual compositor state
  and that minimising does not reveal the hidden workspace or hide the other window.
- Persist a Dock preference and use the actual Omarchy shell restart command.
  Require a changed shell PID, Familiar recovery, surviving windows and preference.
- Exercise window operations again after restart, require the real Dock layer,
  and capture a screenshot.
- Roll back with the production installer, checking the previous source identity,
  removal of the development receipt and live Familiar/window recovery.

The stable bootstrap is a test fixture, not a test of the graphical setup wizard.
This first smoke does not click Dock icons, inspect hover-preview pixels, trigger
notifications, test physical GPUs/displays/trackpads or measure performance.
Those remain explicit future extensions and XPS acceptance checks.

## Reproduction and evidence

The workflow pins the Arch image digest, Arch snapshot date, stable Familiar
commit and Omarchy commit. Its artifact records installed package versions,
source SHA, upstream SHA, phase/exit code, logs, compositor state and screenshots.
The development artifact separately records source, run/attempt and binary hashes.
Third-party Actions version tags not already pinned by the repository remain a
separate supply-chain limitation; this is not a fully hermetic build.

The job has a 20-minute limit and individual readiness deadlines. Diagnostics
upload even on failure. Screenshots prove rendering occurred, not visual fidelity.
`session.sh` refuses to run outside the disposable CI account.

PRs trigger the workflow; manual dispatch becomes available after the workflow
reaches the default branch. The reusable build returns its exact artifact name,
so retrying only a failed desktop job uses the previously successful candidate
artifact, not a guessed new attempt. `tested-build.json` records the producing
attempt separately from the smoke workflow attempt.

Automated desktop success is not XPS hardware acceptance or authorization to
promote a branch to main or publish a version. See `WORKFLOW.md`.
