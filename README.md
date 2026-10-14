# Familiar Desktop — end-of-life transition

**Feature development has ended. New installations are not recommended.**

On 13 October 2026, Tom decided to retire Familiar Desktop after Omarchy
incorporated much of its mouse-friendly desktop functionality into Core.
[v0.1.7](https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/tag/v0.1.7)
subsequently shipped the foreign app-ID icon-loading fix. That release does not
restart the feature roadmap.

As of 14 October, the replacement functionality has merged into **Quattro
development**. This is not a claim that it is available in stable Omarchy or on
your installed desktop. Check your version, channel and official release notes
before migrating. There is no requirement to switch to a development channel.

The source, MIT licence, history and existing releases remain accessible. This
repository is not archived. Existing installations are not remotely disabled or
removed by this announcement.

## Existing users: choose your next step

| Your situation | Next step |
| --- | --- |
| Your installed Omarchy does not yet provide the Core desktop you need | You can keep your existing Familiar installation for now, subject to the support limits below. Plan migration when your channel supplies it; do not force an ABI mismatch or load competing titlebar renderers. |
| Core's replacement is available on your desktop | Back up your settings, restore hidden/minimised windows, disable Familiar, then configure and verify Core before uninstalling. |
| You want to remove Familiar now | Use the installed cleanup script after reading the [EOL and migration guide](docs/END-OF-LIFE.md). You do not need Core's replacement to uninstall, but need another way to launch and restore windows. |
| Setup, disabling or removal fails | Stop at the reported error. Preserve the installed source, matching helper and recovery files; see [troubleshooting](docs/TROUBLESHOOTING.md). Do not delete the plugin directory to bypass cleanup. |

**Start with [the EOL and migration guide](docs/END-OF-LIFE.md)** for backup,
safe disabling, rollback, retained preferences and failure recovery.

For an intact supported installation, the removal entry point is:

```bash
bash "$HOME/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/uninstall.sh"
```

Run it from your normal desktop session as your own user, not with `sudo`.
It restores journalled windows, refuses to proceed with remaining minimised
windows, resets Familiar-owned configuration and removes the plugin only after
cleanup succeeds. The generic `omarchy plugin remove` command alone does not
perform this cleanup. Disabling alone also does not reset all native preferences.

## Maintenance expectations

- No v0.2.0, Mac/Windows split, curated app collection or new feature roadmap is
  planned. The earlier plan in [#87](https://github.com/tcballard/omarchy-plugin-familiar-desktop/issues/87) is superseded.
- Security, safe removal, migration and narrowly scoped compatibility fixes may
  be considered for existing users. There is **no guaranteed response time,
  support period, future release or compatibility with future Omarchy updates**.
- Bug reports remain open where unresolved. An open issue or PR is not a promise
  to fix or ship it. Report sensitive vulnerabilities privately through GitHub's
  security reporting route if available; do not post exploit details publicly.
- Stable release binaries are x86_64. ARM development artifacts and contributor
  work remain available; they do not establish stable ARM desktop support.

See [maintenance policy and contribution review](docs/MAINTENANCE.md).
[Development instructions](docs/DEVELOPMENT.md) remain available for targeted
maintenance and forks, under the existing [validation workflow](docs/WORKFLOW.md).

## Releases, reference and credit

- [Existing releases](https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases), [v0.1.7 notes](docs/v0.1.7.md), and [v0.1.6 notes and thanks](docs/v0.1.6.md).
- [Pre-retirement usage reference](https://github.com/tcballard/omarchy-plugin-familiar-desktop/blob/v0.1.7/README.md): historical installation and feature documentation, **not current maintenance promises**.
- [Configuration ownership and rollback](docs/ROLLBACK.md), [titlebar migration](docs/TITLEBAR-MIGRATION.md), and [architecture](docs/ARCHITECTURE.md).

Thank you to everyone who contributed code, reports and testing. In particular,
@nixfred's installer, input/PWA and drag fixes were integrated through #92;
@k-kostin contributed ARM development support; @luinbytes's drag-axis fix remains
under review. [The maintenance record](docs/MAINTENANCE.md) distinguishes shipped
work from outstanding proposals and retains links to the original contributions.

Familiar derives from [rosakodu/omarchy-dock](https://github.com/rosakodu/omarchy-dock)
at `467070386fe60e173295020d3911176202b3e0c9`. MIT licensed; original work
© 2026 rosakodu, Familiar Desktop changes © 2026 Tom Ballard. See [LICENSE](LICENSE).
