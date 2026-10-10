# v0.1.5 release preparation

Prepared on `v0.1.5`, [PR #81](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/81), at Tom's request on 10 October 2026. General, Windows and Mac layouts remain in scope. The Mac-only proposal and further decomposition of the largest components are deferred. Full official-titlebar migration (#74) remains separate.

## Tested development boundary

Source: `87a81d702360a0f02a242772c2fe1a6d1152146b`; tree: `5c5d51982bf7738b48c081067d7f016e9a9efb95`. This development build still reports product version 0.1.4.

Tom reported after installing and testing this candidate:

> OK, everything seems to be working...

He then requested release preparation and deferred the Mac-only work:

> Yeah ok, lets prep for this then - we are gonna defer the mac-only astuff

These are overall test feedback and authorization to prepare the release. No individual checklist results, current XPS model, installed Omarchy/Hyprland versions, scaling or rollback snapshot path were supplied in this report. Do not substitute the previous release's environment or infer physical keyboard/trackpad, multi-monitor or Qt 6.12 results. Merge and final publication remain separately authorized under [WORKFLOW.md](WORKFLOW.md).

All of the following passed for the tested source, attempt 1:

| Evidence | Run |
| --- | --- |
| Portable checks, PR | [38068482802](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38068482802) |
| Portable checks, push | [38068480050](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38068480050) |
| Binary validation | [38068483012](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38068483012) |
| Development bundle | [38068482995](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38068482995) |
| Three desktop smoke jobs | [38068483132](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38068483132) |

Downloaded development artifact: `familiar-dev-87a81d702360a0f02a242772c2fe1a6d1152146b-38068482995-1`, artifact `11676002510`; ZIP SHA-256 `3176b335476ba6e0592548cf7509885072439f824938f2b11140036c4febb023`. GitHub's digest, every `SHA256SUMS` entry and `DEV-BUILD.json` source/run/attempt matched. Backend SHA-256: `4f7dc35d82fe774ae91d8fa11b8c910496ec56cf2cb7755b2c6d6cfa6b983578`. Hyprbars SHA-256: `7eb0f6162b7342346a9a7c309d067d1634d79dfd71a5ec3c0132d46635b3dc06`.

Downloaded desktop receipts matched that source/run/attempt and both binary digests. All reported `phase: passed`, `exitCode: 0` and a separate, active RSS panel with glyph U+F09E.

| Omarchy Core | Qt / Quickshell | Artifact | ZIP SHA-256 |
| --- | --- | --- | --- |
| `0f8af9be307d5d4f12cc0f6394892cac651ed5e6` | 6.11.2 / 0.3.1 | `11675786898` | `69f728c16311e3e41cf20786a72ec26bae34647c8e9e25ab97aa7cf24f0ab991` |
| `f99d33a8ddee7b36509a71a6d20d5d23355ce8b1` | 6.11.2 / 0.3.1 | `11675353917` | `150a4d203960904d688ef17a9aeed618a2b0e48d393956e6acf2882bd36239ca` |
| `b83d3df0840504299d3099ebf391eb8110527edd` | 6.12.0 / 0.3.2 | `11675933039` | `715baea2cd267dbcb24fbb6e67769743c1cbb93739712214f21d3db8fd6e451a` |

Local checks at this boundary also passed Rust formatting/Clippy, the existing Node groups, 306 QtTest cases, six production settings/bar render cases and QML parsing. The canonical local check encountered the recorded process-visibility restriction; canonical CI passed with that test enabled.

## Release changes and remaining gates

Preparation changes version metadata to 0.1.5, the three versioned download selectors, release documents and README status. Production QML/JavaScript and Rust implementation must remain byte-identical to the tested development boundary. The version change alters the backend executable; the old development digest must not become the 0.1.5 release pin.

- [x] Release scope and reporter acknowledgements prepared in [v0.1.5.md](v0.1.5.md).
- [x] Positive XPS result recorded for the development boundary above.
- [ ] Measure the 0.1.5 backend from source-bound CI and commit its reviewed digest; retain the independently checked Hyprbars digest.
- [ ] Rebuild and verify a strict `familiar-desktop-release` artifact with `sourcePinsMatch: true`, complete checksums and both actual installers.
- [ ] Record current-source portable/build/desktop evidence and inspect the release-only diff against the tested boundary.
- [ ] Record acceptance of the final candidate and Tom's merge authorization.
- [ ] Require green merged-main checks and matching source/binary identities.
- [ ] Record separate authorization for final v0.1.5 publication; remove the pending notice only when promotion is authorized.
- [ ] Dispatch **Tag verified release** for the exact accepted main SHA, with RC empty, then verify uploaded/public assets and fresh setup/retry.
- [ ] Publish prepared issue follow-ups only when authorized and the claimed release exists.

No v0.1.5 tag, GitHub Release, marketplace submission or public download is created by preparation. Final tag/asset identities and the merged-main SHA must be recorded after those actions, rather than guessed in advance. Follow [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md). Development installation and rollback use [DEVELOPMENT.md](DEVELOPMENT.md); keep the snapshot path printed by the installer.

## Static preflight boundary

The installed release preflight was run against a clean clone of the tested source. Its schema checks found no manifest/path errors; its advisory security scan returned `sudoers-dangerous-passwordless-command` for the disposable desktop VM's `tests/desktop/vm.sh` fixture. Manual inspection confirms that cloud-init grants this permission inside the temporary guest overlay, with a checksum-pinned base image, localhost-only SSH forwarding, no host-directory mount, and cleanup of guest disks and ephemeral keys. The preflight still returns failure for the fixture rule; this is not a passing scan or a claim of runtime security. Installer, process, workflow dependency and distributed agent-instruction advisories remain limited scan results. No scanner rule was suppressed or changed. The initial run against the development checkout also hit its safety limit on local `backend/target` output; the clean clone avoided those generated files.

## Follow-up scope

[Prepared issue messages](RELEASE-0.1.5-FOLLOWUPS.md) distinguish the five included fixes from #74 and the eighteen future Dock enhancements under #46. The earlier code review also identified possible repeated hosted-widget signal attachment, overlapping refresh work and a legacy launch-focus dispatch path. They are review concerns, with no XPS reproduction recorded in this report; release preparation does not claim to fix them or complete broader dock parity.
