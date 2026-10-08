# v0.1.3 release evidence

Accepted runtime source: `44cb951a30580ed3acd45bfb6edd233937106423`, PR #69.

On 8 October 2026 at 17:17 BST, Tom reported: “Okay, I’ve done my testing of this as well now and I am ready to merge the branch into main and cut v0.1.3 :)”. This records owner acceptance and authorization for both merge and release. Detailed per-scenario results, OS versions and display configuration were not supplied; no exhaustive coverage is inferred.

All four candidate workflows passed. Desktop smoke run 37746837241 attempt 2 verified install, window actions, opacity persistence, native taskbar, restart, profile restoration and active-taskbar rollback. Its bundle ZIP SHA-256 is `79a4765b95197804d8f0c8061b268a1071fff2f75453d99886f8629a020fc1fe`.

Release-only changes: manifest/backend version 0.1.3, matching installer URLs, rebuilt backend checksum pin, current release documents and README, and packaging document filenames. Runtime source/QML is unchanged from the accepted candidate.

Publication requires green current Portable checks and Release binaries, reviewed source pins matching rebuilt artifacts, and an immutable annotated v0.1.3 tag at the final main SHA. Packaging creates source/release manifests, SBOM and complete SHA256SUMS. The previous backend pin remains until the version-bump build is measured, then a further build must reproduce that digest. No gate is disabled.

Full official-titlebar migration remains #74 for v0.1.4. Safeguards do not establish loaded-backend provenance or full shared-package compatibility.
