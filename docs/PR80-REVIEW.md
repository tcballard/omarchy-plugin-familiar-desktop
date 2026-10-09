# PR #80 integration review

Reviewed source: `8ff9cd0d1bed04f2c2efb8b394160aa8fcfc444c`, Matteo Murgida’s [PR #80](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/80). Integrated into `v0.1.3-hotfix` with a cherry-pick preserving authorship. No merge to main or release was performed.

The diagnosis is confirmed: v0.1.3 is a draft release, and the public backend URL returns HTTP 404. The PR’s exact-URL diagnostics and committed-digest download tests are useful and retained.

## Findings corrected on the integration branch

1. **Release blocker:** publishing with the workflow’s `GITHUB_TOKEN` does not trigger the `release: published` job. The proposed final path would publish an empty release and wait for assets that no job uploads. [GitHub documents this event suppression](https://docs.github.com/en/actions/concepts/security/github_token#when-github_token-triggers-workflow-runs). Final publication now downloads the verified main build, checks source identity and reviewed pins, uploads all assets into a draft, reads them back, and only then publishes and verifies public URLs in the same job. Failed readback leaves the release unpublished.
2. **Incomplete release visible to users:** publication previously preceded asset availability, exposing another 404 window. Upload and readback now precede publication; regression fixtures assert that ordering and refusal on missing, corrupt, unreviewed, wrong-version or wrong-source artifacts.
3. **Smoke-check fidelity:** the verifier reconstructed expected URLs without checking the installer’s base URL or library naming pattern. It now checks those contracts so a wrong download repository cannot pass unnoticed. Unsafe asset paths are rejected.
4. **Failed-download cleanup:** `process.exit()` bypassed the verifier’s `finally` cleanup. Failures now unwind through cleanup, with tests for success and failure. Downloaded backend version probing is bounded.

These fixes are tested without GitHub mutations. Live public download checks remain a publication gate, not something pre-release fixtures can prove. A separately authorized recovery of v0.1.3 would require its own matching tag assets; publishing v0.1.4 does not make old v0.1.3 URLs work.
