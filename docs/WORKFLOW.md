# Stable main, tested feature branches

Agreed with Tom on 7 October 2026. This is Familiar's default workflow and the
source of truth for future assistant sessions, contributor work and handoffs.

1. Start a feature branch from `main` and open a draft PR. Keep related changes
   together; use a temporary integration branch for combined acceptance.
2. Implement and run CI. Request an ad-hoc development build of the branch when
   ready for desktop testing, without changing the product version.
3. Identify the test build by its full commit SHA, CI run URL and attempt, and
   artifact name/digest. Its source and binaries must match. Include rollback.
4. Tom tests that exact build on the XPS. Record scenarios, environment, results,
   limitations and his explicit acceptance or rejection in the PR.
5. Fixes remain on the branch. Each new source/build needs fresh acceptance for
   affected behaviour. A stale approval, label or checked box is not acceptance
   of a later commit. If the merge changes the accepted content, retest it.
6. Merge only with current green CI, applicable desktop acceptance and Tom's
   merge authorization. Green CI alone is never enough for runtime changes.
7. Create a versioned release only when separately requested. Routine test builds
   create no RC tags, GitHub Releases, version bumps or stable binary-pin changes.

Documentation/process-only changes can be validated without desktop testing.
State why live testing is inapplicable. Do not use that exception for installer,
packaging, workflow execution or runtime changes.

## Acceptance record

- Branch, PR and full source SHA.
- CI run URL, attempt and artifact name/digest.
- XPS model, Omarchy / Hyprland versions and monitor scaling.
- Scenarios tested, outcome and remaining limitations.
- Tom's explicit decision and a link or quotation identifying its provenance.
- Merge authorization; release authorization is separate.

Assistant summaries and handoffs must preserve this workflow and distinguish
automated tests from desktop acceptance. Never claim permanent account-wide
memory; future project sessions should read `AGENTS.md` and this file.

## GitHub enforcement

The repository instructions and PR template enforce the working agreement for
contributors and assistants. GitHub rules are a separate server-side setting.
The prepared ruleset in `.github/rulesets/stable-main.json` requires PRs and the
portable `test` check, resolves review threads, and blocks force pushes and branch
deletion. It provides no bypass actors. Importing a file does not activate a rule:
apply it in Settings → Rules → Rulesets, then read back its active state.

This baseline does not claim to mechanically verify XPS acceptance or every
binary workflow. Those remain explicit pre-merge checks under the agreement
above. A required peer approval would not let Tom approve PRs he authored;
do not substitute that requirement for his acceptance record.

At adoption, branch protection has NOT been configured through this session:
the available GitHub connector lacks settings controls. The manual-build
implementation is draft PR #43, awaiting XPS acceptance. Do not merge that runtime
change merely to activate this policy. GitHub's manual-dispatch button becomes
available once the accepted workflow reaches the default branch.

Reference: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
