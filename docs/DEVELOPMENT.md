# Branch builds and desktop acceptance

Work on a feature branch with a draft PR. Green CI means ready for desktop
testing. Merge only after Tom accepts the exact build on the XPS and CI passes.
Changing the source invalidates acceptance for affected behaviour. Versions and
release tags are a separate, explicitly requested step. Do not create RC releases
for routine testing or treat a development artifact as a stable installer.

## Build when needed

Once this workflow has been accepted and merged to the default branch, open
Actions → Build for testing → Run workflow and select your feature branch.
The branch must contain the workflow and development installer support.
Alternatively:

```bash
gh workflow run dev-build.yml \
  --repo tcballard/omarchy-plugin-familiar-desktop \
  --ref feat/your-feature
gh run list --repo tcballard/omarchy-plugin-familiar-desktop \
  --workflow dev-build.yml --branch feat/your-feature
```

The workflow runs the portable suite, QML checks and binary builds. Only after
both reusable workflows succeed does it publish the `familiar-dev-SHA-RUN-ATTEMPT`
artifact. It has matching static backend and Hyprbars binaries, an immutable
source identity, an installer, checksums and build receipt. It creates no release,
tag or version change. Artifacts expire after 30 days: keep the downloaded bundle
and your acceptance evidence. Rebuilds are new evidence, even at the same SHA.

GitHub requires the manual workflow to exist on the default branch first. The
PR path trigger exercises this pipeline before that bootstrap merge. Runtime
changes still require live acceptance; repository branch protection is managed
separately and is not changed by this workflow.

## Download and install on the XPS

Use the run ID printed by GitHub. Inspect its source SHA and confirm all jobs
passed. Download only a run from a branch you trust: its installer and binaries
are executable code. Checksums detect corruption; they do not make an untrusted
branch safe. GitHub authentication is required to download Actions artifacts.

```bash
repo=tcballard/omarchy-plugin-familiar-desktop
run_id=REPLACE_WITH_RUN_ID
artifact_name=REPLACE_WITH_FAMILIAR_DEV_ARTIFACT_NAME
gh run watch "$run_id" --repo "$repo" --exit-status
test_dir="$(mktemp -d "$HOME/familiar-dev.XXXXXXXX")"
gh run download "$run_id" --repo "$repo" \
  --name "$artifact_name" --dir "$test_dir"
cd "$test_dir"
sha256sum --check --strict SHA256SUMS
cat DEV-BUILD.json
bash install-dev.sh
```

Requires an existing, working Familiar installation on the supported Linux
x86_64 / Hyprland ABI, with git, jq and the usual Omarchy tools. No compiler is
needed. Local source changes and unexpected ignored files stop installation.
The installer recovers minimised windows, disables window controls and the plugin,
checks out the exact source, installs matching binaries and restarts the shell.
It retains pins, dock settings and the saved mac/windows titlebar style.

Stable release checksums stay unchanged. A local receipt binds development
binary hashes to the installed source SHA and directory. Setup accepts it only
for a clean matching checkout. In-app release repair is unavailable during dev
testing; use this installer to update or roll back. Do not run the normal plugin
updater during a development test; moving the source invalidates its receipt.

## Roll back

Keep the bundle directory. From it:

```bash
bash install-dev.sh --rollback
```

The installer prints an explicit snapshot path for each installation; pass it
after `--rollback` to select that point. A snapshot retains the previous commit,
both binaries and any previous development receipt. Rollback
verifies those bytes and restores them together, including after a failed setup.
User preferences are not reverted wholesale. Snapshots remain under
`~/.local/state/familiar-desktop/dev-snapshots` (or `$XDG_STATE_HOME`).
Failures stop before enablement where possible and print recovery instructions.
Do not delete a snapshot while you still need its rollback point.

## Record acceptance in the PR

- Commit SHA, CI run URL and attempt; artifact name/digest from GitHub.
- XPS / Omarchy / Hyprland versions and monitor scaling.
- Scenarios exercised, result and remaining limitations.
- Explicit accept/reject decision for that build.

For hover previews and widget placement, use `docs/DOCK-PREVIEWS.md`.
For this installer, exercise stable → dev, dev → dev, failed setup recovery and
dev → previous install. Mock desktop tests do not establish live shell behaviour.
