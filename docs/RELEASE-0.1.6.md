# v0.1.6 release record

## Acceptance and authorization

On 12 October 2026, Tom reported:

> so i have finished testing familiar v0.1.6 on PR 92 so we are ready to merge, tag, release, etc

This records desktop acceptance of [PR #92](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/92), whose head was `744df12d4788d7bf2937bec85c41a880d7a7f251`, and authorization to prepare, merge, tag and publish v0.1.6 after the required checks. No individual test checklist, current device/software versions, monitor scaling or snapshot path was supplied in this message; no such details are inferred. ARM desktop acceptance is not claimed.

The development candidate still reported 0.1.5. Release preparation changes package version metadata, three versioned download selectors, reviewed binary pins and documentation. Runtime QML/JavaScript and Rust implementation stay identical to the accepted boundary. This scoped release authorization covers those necessary promotion steps; it does not authorize unrelated runtime fixes.

## Accepted build evidence

All current checks were read back from GitHub before release preparation: 26 successful jobs and one intentionally skipped publication job.

| Evidence | Run (attempt 1) |
| --- | --- |
| Portable checks, x86_64 and aarch64 | [38231500359](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38231500359) |
| Binary validation | [38231500672](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38231500672) |
| Source-bound development bundles | [38231500686](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38231500686) |
| Four desktop smoke cases | [38231500922](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38231500922) |

The PR records development artifact `familiar-dev-744df12d4788d7bf2937bec85c41a880d7a7f251-38231500686-1`, ZIP SHA-256 `1bfb2de891ef4bc567b2f21d70a35211feda68df9fbafb13b34b27344fb651b6`, and backend SHA-256 `a74cbbd1b36c310f2e409294dbb5c2356f3533fab5bf99147e442996bc1ac0ee`. These are the accepted development identities, not release-version pins. The earlier artifact verification is documented in the PR; it is not claimed to have been repeated during this release-preparation session.

The desktop matrix includes Qt 6.12.0 / Quickshell 0.3.2 and official titlebars v0.2.1. ARM portable CI and a static development bundle are separate from physical ARM acceptance. See [contributor integration review](CONTRIBUTOR-REVIEW-2026-10-12.md) for included and deferred changes.

## Promotion gates

- [x] Tom accepted the candidate and authorized merge/tag/release.
- [x] Current accepted-source CI is green.
- [x] Measure the release-version backend from CI and commit its reviewed digest.
- [ ] Rebuild a strict release bundle reproducing the source pins.
- [ ] Verify current release-candidate checks and review the metadata-only diff.
- [ ] Merge and require successful current-main portable and binary workflows.
- [ ] Dispatch **Tag verified release**, with RC empty, and verify public assets.
- [ ] Complete public-download setup/retry verification and marketplace follow-up.

Exact later source identities and results belong in PR #92 after they exist. A passing validation-only build is not publishable. Follow [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md); never move a published tag or replace immutable assets.

## Release-version measurement

Source `a2f56347cb615c41ab291b9048707f04e4754f85`, [binary run 38259666459](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38259666459), attempt 1, [job 114847248291](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38259666459/job/114847248291) built the static 0.1.6 backend and recorded SHA-256 `2c9aee02270eee876aaff933a6a459867397e097182a5008a0d2b36294cb9470`. The job passed its Rust suite, static ELF check, manifest/version packaging checks, validation-only installer tests and complete checksum verification. Measurement was read from the CI job log; no local byte-for-byte artifact inspection is claimed here.

The measured backend digest is now committed in `release-binaries.sha256`; the existing independently reviewed private-renderer pin is retained. The measurement artifact `11751383907` (`familiar-desktop-packaging-validation`) is not publishable. A new build must reproduce both committed pins and pass the strict release installer smoke test before merge/publication.
