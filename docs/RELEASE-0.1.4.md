# v0.1.4 release preparation

Prepared at Tom’s request on 9 October 2026 on `v0.1.3-hotfix`, draft PR #77. This combines the desktop hotfix and Matteo Murgida’s PR #80, cherry-picked with original authorship, plus the review corrections recorded in [PR80-REVIEW.md](PR80-REVIEW.md).

Tom requested his own smoke test before proceeding. Acceptance, merge authorization and publication authorization are pending. The earlier XPS verification applies to `a8e6eb61b5744350c319c217231f5bd270988260`, not automatically to the combined candidate.

Version preparation updates manifest/Cargo metadata and installer URLs to 0.1.4. The static backend digest must be measured from CI and committed, then reproduced by a new green build before publication. Hyprbars retains its reviewed digest. No tag is created or moved during preparation; main and v0.1.3 remain unchanged.

Use an exact-SHA development bundle for pre-release XPS testing. Do not run the public release installers before v0.1.4 is published, mix QML and binaries, remove the development receipt, or substitute CI assets for reviewed pins on an end-user install. Follow [HOTFIX-SMOKE.md](HOTFIX-SMOKE.md) and [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md).
