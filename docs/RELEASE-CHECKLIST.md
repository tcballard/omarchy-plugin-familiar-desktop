# Release and Merge and Tell checklist

## Prepare and accept

- Keep work on the feature/hotfix branch and draft PR. Record the exact tested source SHA, CI run/attempt, artifact digest and rollback snapshot.
- Measure the release-version backend from CI, commit its reviewed digest, and require a new build to reproduce all pins. Validation-only artifacts cannot be released.
- Obtain Tom’s explicit desktop acceptance of the combined build, then separate merge and release authorization. Green CI is not acceptance.
- After merge, require green current-main Portable checks and Release binaries. Confirm the resulting content is the accepted content; retest if it differs.

## Publish only when authorized

- Review `docs/v<version>.md`, including thanks, compatibility limits and the exact issues addressed. Remove the pending-publication notice only when acceptance and authorization are recorded.
- Explicitly dispatch **Tag verified release** on the accepted main SHA, leaving RC empty for the final release. This now publishes, not merely tags. Never dispatch it merely to request a test build.
- The job downloads the verified main artifact, checks manifests and independent source pins, creates an immutable tag, uploads every asset to a draft and compares readback bytes before publication. It then checks the actual public onboarding URLs. It does not depend on another workflow being triggered by `GITHUB_TOKEN`.
- If upload/readback fails after tag creation, retain the immutable tag and unpublished draft. Inspect the failed job and recover only with that exact source and matching artifact; never move the tag or clobber an existing asset. A normal rerun intentionally refuses an existing tag.
- If public URL verification fails after publication, do not announce success. Inspect the HTTP error and asset digests, preserve evidence and resolve the delivery problem. Do not upload different bytes under the same identity.
- Verify fresh setup and retry after a failed download in a disposable environment. Existing v0.1.3 checkouts still request v0.1.3 assets; they must update to v0.1.4 unless recovery of v0.1.3 is separately authorized.

## Merge and Tell

- Include a **Thanks** section in every release note: credit contributors by name/handle and link their PRs; credit reporters and reproduction/testing help with issue/comment links. Check the actual scoped issues and commit authors rather than copying a generic contributor list.
- Distinguish resolved issues from follow-ups and partial improvements. Do not mark #79 publicly fixed until anonymous downloads and fresh setup pass.
- Prepare a short explanation for each affected issue/PR with the fix, released version and verification. Send those follow-ups only when authorized; preparation is not permission to post messages or close issues.
- Record Tom’s acceptance and merge/release authorization; keep the release notes and PR description consistent with the final implementation and validation.
