# v0.1.2 release evidence

Accepted desktop candidate: v0.1.1-rc.4, full SHA `812f7a7a878be8f7b71c6f49feb52357cd1d7421`.

Owner acceptance: Tom reported testing complete and good enough, and authorized the stable release on 6 October 2026. No per-step fresh-profile lifecycle record, exhaustive monitor/scaling coverage, or marketplace approval is inferred.

Release-only changes: manifest and backend version 0.1.2, matching installer release URLs, rebuilt backend checksum pin, current release documents and README, and CI checksum diagnostics. Runtime source/QML behaviour is unchanged from the accepted candidate.

Publication requires green Portable checks and Release binaries on the final main SHA. Packaging rejects backend/Hyprbars bytes that differ from source pins, checks binary version and creates source/release manifests, SBOM and SHA256SUMS. The version tag is annotated and must not replace an existing tag.

The new backend digest is measured from the version-bump build, recorded in reviewed source, then verified by another build. The previous backend pin is deliberately retained until that measurement; no verification gate is disabled.
