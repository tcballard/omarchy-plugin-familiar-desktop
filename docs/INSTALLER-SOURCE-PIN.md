# Installer source and binary identity

## In-app setup candidate

Native `omarchy plugin add` clones the repository default branch; it does not pin a release tag or install binaries. Familiar checks local binary digests before showing its dock and opens a first-run setup screen when setup is incomplete. The user explicitly starts downloads in that screen. The bundled `setup-in-app.sh` runs the same source-pinned download installers and never fetches a new source checkout, opens a terminal, or invokes a package manager.

Setup is serialized by a filesystem lock. An incomplete marker persists across interruption; errors and bounded diagnostic output return to the screen. Setup does not disable/re-enable the plugin or restart the shell hosting it. Existing downloads are only executed after checking their committed digest. The current UI candidate intentionally reuses the reviewed v0.1.1 backend and Hyprbars assets; it does not change their pins.

This is a change to the reviewed network/process execution path and requires marketplace re-review as well as live native-install acceptance.

## v0.1.1 review candidate

`release-binaries.sha256` records the expected backend executable and Hyprbars
library digests in Git. Both download installers read that local reviewed file;
they no longer fetch the expected digest from release assets. Missing, ambiguous,
malformed or mismatched digests stop installation before running the downloaded
backend, including `--version`, or installing the library. Repair uses these same
installers in the installed checkout.

The pins were calculated from the successful main build of source
`d35071b351b6646f5b73640cc8c8fe6ef2701d8b`, Actions run `37494902701`, artifact
`11427890281` (`familiar-desktop-release`). Its ZIP digest was
`f8e74d8017ab1cf10273accfaa8eac3c212b6c592a87aebb751f7cd7d4088932`.
No Rust runtime or Hyprbars source changes accompany this installer fix.
The artifact metadata is provenance, not the runtime trust anchor: the reviewed
Git digests are authoritative even if a release asset and SHA256SUMS both change.

Release packaging checks the rebuilt binaries against these pins and fails
closed on a difference. A changed runtime, dependency or toolchain may require a
new candidate build and an explicit review of new digests. Never automatically
rewrite the pins during final release publication. A version string alone is
not sufficient evidence of binary identity.

PR and main builds use `scripts/prepare-release.cjs BINARY --ci` to validate
unreleased packaging without changing these pins. The existing release manifest
records `sourcePinsMatch` for the backend and every packaged Hyprbars library.
Missing, malformed or duplicate pins still fail; only valid digest differences
are allowed in this mode. Source provenance, notices, version, package completeness
and checksum checks remain required.

When pins differ, CI uploads `familiar-desktop-packaging-validation`, without
installers or release instructions. The installer smoke check uses built-asset
digests only inside its disposable fixture; this is not source-pin approval.
When every binary matches, CI retains the strictly verified
`familiar-desktop-release` artifact and the committed-pin installer smoke check.
RC tagging consumes only that strict artifact and stops before creating a tag
if it is absent. Default packaging and published release events remain strict,
with no fallback to CI mode. Green development CI does not mean release readiness.

The candidate installer independently fetches the exact embedded source commit
and reads its digest file with `git show` before executing either bundled binary.
The bundle's SHA256SUMS still checks transport integrity; it is not an independent
trust anchor. Obtain the installer itself from a trusted, verified build or a
commit-pinned source bootstrap. Replacing an entire unverified installer can
replace its checks; this change does not authenticate arbitrary downloaded shell
scripts, defend against a compromised reviewed source, or provide signatures.

The standalone install.sh remains a template; CI inserts the exact source SHA.
Before publishing final installation instructions, pin the bootstrap itself to
reviewed source or authenticate its bytes independently. Do not advertise a
mutable release install.sh URL as a commit-pinned trust root.

## v0.1.0 history

The bootstrap at `57b6fc07b2221357f7d93e031940123e41f37b2c` installs desktop source
`bda1ec617966b11fb8470788c74019350b38838f`. That fixes Git identity but its installed
download scripts trust checksums from the same mutable release as the binaries.
It does not fix the marketplace finding. Existing v0.1.0 installations and release
assets are unchanged. The README no longer recommends it as hardened installation.

## Validation

Installer regression tests replace both downloaded bytes and their remote
checksum and confirm rejection against the unchanged source pin. Backend
rejection occurs before execution; Hyprbars rejection occurs before title-bar
setup. Candidate tests also replace the executable and bundle SHA256SUMS together.
Existing real-Git tests cover moved tags/default branches and source mismatches.
The actual release-asset test exercises both download installers without build
tools. These automated checks do not replace live XPS acceptance or marketplace
approval.
