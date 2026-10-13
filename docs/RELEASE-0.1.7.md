# Familiar Desktop 0.1.7 release evidence

## Scope and authorization

The only runtime change since v0.1.6 is the icon fix from PR #96, head `9064299ec196ed03cf0371516b3ffad31b5a5b27`, merged at `5f7eaedf4e195d9c27571a6f6b6bf1db73cf40ed`. Tom explicitly authorized merging after smoke tests passed on 13 October 2026. All four desktop configurations passed; no physical XPS acceptance is inferred.

Tom then requested shipping a bug patch and selected v0.1.7 instead of a four-part version, preserving Cargo and release-pipeline compatibility. This authorizes necessary version metadata, versioned download selectors, measured binary pins, release-only merging, an immutable tag and publication after verification. It does not authorize unrelated runtime changes or a permanent waiver of desktop acceptance.

## Runtime evidence

All runs below passed for the PR #96 head, attempt 1:

- [Portable checks #377](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38362444952): canonical Rust, Node and Qt checks on x86_64 and aarch64.
- [Binary build #198](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38362445333).
- [Desktop smoke #64](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38362445739): all four configurations, including Qt 6.12 and official titlebars.

Production QML/JS and Rust implementation remain identical to that merged runtime. Promotion changes only versions, download selectors, source pins and documentation. Stable binaries remain x86_64.

## Promotion status

Release-version backend measurement, strict pin reproduction, exact-main checks and verified publication must complete before shipping. Their exact source/run/digest identities will be recorded in the release PR and appended to the published notes by the publication workflow. No unchecked gate is claimed complete.

## Release-version measurement

Source `0f39b99d5b4b24b425566e1e4bde410cab20537f`, [binary run 38441119339](https://github.com/tcballard/omarchy-plugin-familiar-desktop/actions/runs/38441119339), attempt 1, job `115448274187` built the static 0.1.7 backend with SHA-256 `11d63ea8077cf7c3fb001e746efe56aa309cd36dc9b527290dda6462faa92870`. Rust tests, static ELF checks, version checks, validation-only packaging fixtures and checksums passed. The digest was read from the CI log; independent local byte inspection is not claimed. The validation-only artifact is not publishable.

The measured backend pin is committed; the reviewed private titlebar-library pin remains unchanged. A subsequent strict build must reproduce both before promotion.
