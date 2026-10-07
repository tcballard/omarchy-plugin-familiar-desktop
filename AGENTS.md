# Familiar development workflow

- Work on feature branches and open draft PRs. Keep `main` for accepted work.
- Green CI means ready for testing, not permission to merge. Runtime changes
  require Tom's explicit desktop acceptance of the exact source/build, followed
  by merge authorization. Report automated and live evidence separately.
- Use the Build for testing workflow and `docs/DEVELOPMENT.md` for branch builds.
  Do not create RC tags, releases, version bumps or change stable binary pins for
  ordinary testing. Release work requires an explicit request.
- Preserve local changes and user configuration. Test installer failure and
  rollback paths when modifying installation or development receipt handling.
- Use Rust for backend changes; do not introduce Python tooling.
