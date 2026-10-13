# v0.1.7 security maintenance release record

## Scope and authorization

This release promotes merged PR #96 from main `5f7eaed` with release-only version metadata, versioned download selectors, measured binary pins and documentation. Runtime implementation remains the merged security-fix boundary.

Tom authorized PR #96's merge if smoke tests passed on 13 October 2026, and subsequently requested: “Yeah, do the release containing 96 then”. This covers the necessary release preparation, merge, tag and publication. It does not claim physical XPS acceptance. The proposed four-part v0.1.6.1 number is represented as the next semantic-version patch, v0.1.7, required by the manifest validator, Cargo and existing release tooling.

## Security-fix evidence

Exact tested source: `9064299ec196ed03cf0371516b3ffad31b5a5b27`; tree `de03a9129a17704d0dc5278a2dce0d53eabe327b`.

- [Portable checks 38362444952](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38362444952): Rust, Node and Qt checks on x86_64 and aarch64.
- [Binary validation 38362445333](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38362445333).
- [Desktop smoke 38362445739, attempt 1](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38362445739): four disposable desktop configurations, including Qt 6.12 / Quickshell 0.3.2 and official titlebars.

No physical XPS or ARM desktop acceptance is claimed. Stable release binaries remain x86_64. Marketplace verification is separate from publication.

## Promotion

The release-version binary must first be measured by CI, its digest committed, and a subsequent strict build must reproduce both committed binary pins. Current main portable and release-binary checks must pass before the existing Tag verified release workflow creates an immutable annotated tag, verifies draft assets and public onboarding downloads.

Exact promotion source, build identities and publication results are recorded in the release-preparation PR and the published release. Validation-only artifacts are not publishable.
