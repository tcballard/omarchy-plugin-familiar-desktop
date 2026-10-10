# Familiar's default development workflow

Read `docs/WORKFLOW.md` before making changes or merging. Use
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for owners, entry points and tests;
`tests/check` is the canonical portable check command. This is the standing
workflow agreed with Tom on 7 October 2026. Carry it into handoffs and summaries;
do not fall back to earlier instructions treating green CI alone as merge approval.

- Keep `main` stable. Start coherent changes on feature branches and draft PRs.
  Use a temporary integration branch when related features need testing together.
- Green CI means ready for desktop testing. It is not desktop acceptance and
  does not, by itself, authorize merging.
- Use ad-hoc development artifacts identified by exact commit SHA, CI run and
  attempt, with matching source/binaries, checksums and rollback. Do not mix a new
  source checkout with old binaries and call that a complete development test.
- Runtime and installer changes require Tom's explicit acceptance of that build
  on the XPS, then merge authorization and green current CI. Never manufacture an
  acceptance record or mark a checklist complete on Tom's behalf without evidence.
- Subsequent changes require a new build and relevant retesting. Documentation
  or process changes may proceed without desktop testing when no runtime or
  installer behaviour changes; record that rationale rather than inventing a test.
- Routine development must not create RC tags, releases, version bumps or edits
  to stable binary pins. A versioned release is a separately authorized action.
- Preserve local changes and user configuration. Exercise failure and rollback
  paths when modifying installation or development receipt handling.
- Use Rust for backend changes; do not introduce Python tooling.
- For each handoff, state the branch/PR, source SHA, CI/build evidence, desktop
  acceptance status, outstanding work and whether merge/release is authorized.

An explicit later instruction from Tom can change this workflow. Record the
scope of any exception; do not infer a permanent waiver from a one-off request.
