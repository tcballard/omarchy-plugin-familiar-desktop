# Maintenance during retirement

Effective decision: 13 October 2026. Review: 14 October 2026.

Familiar Desktop is moving to end of life because Omarchy Core now implements
much of the mouse-friendly desktop direction in Quattro development. Stable
availability must be checked independently. New installation is discouraged;
[existing-user migration and removal](END-OF-LIFE.md) take priority.

## Scope and expectations

Feature development has ended. The v0.2.0 dock-only roadmap, Windows/Mac split,
curated app collection and expansion of platform support are no longer planned.
No replacement fork, new maintainer, future release, response SLA or support
end date is promised. Existing bugs are not declared fixed by retirement.

Security, data/configuration preservation, safe disable/uninstall, migration and
narrow compatibility fixes for existing installations may be considered. Review
cost and risk still matter. A retained PR is a candidate, not accepted code or a
release commitment. Keep sensitive vulnerability details out of public issues;
use the repository's private GitHub security reporting route if available.

[WORKFLOW.md](WORKFLOW.md) still applies: feature branches and review, current CI,
exact-build desktop acceptance for runtime/installer changes, and explicit merge
and separate release authorization. Documentation-only changes need no invented
desktop acceptance. Tests, builds, release assets and binary pins are retained;
this transition does not change runtime, installers or workflow execution.

## Contribution disposition

Reviewed against main `7b7a37f` and the v0.1.6 integration in
[#92](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/92).
Original PR discussions, commits and credit remain accessible.

| Contribution | Disposition and evidence |
| --- | --- |
| [#89](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/89), @nixfred: installer/uninstall fixes | Integrated through #92: XDG fixture isolation `451bfe8`, Show Desktop restoration `e842c70`, stale receipt removal `8ea4055`, physical setup paths `770fa18`. The old official-package refusal was adapted to the supported official-renderer path in `a921b59`, not copied as an obsolete blanket refusal. Close original PR as superseded by that integration; keep credit in commits and v0.1.6 notes. |
| [#90](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/90), @nixfred: Caps Lock markers and PWA profiles | Both integrated through #92: `8491c19` and `6d4c34b`. These preserve uninstall correctness and exact profile matching. Close original PR as already integrated; this is not rejection of the work. |
| [#91](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/91), @nixfred: drag cleanup and CLI attribution | Drag cleanup shipped in `0e3e06b`. Keep PR open for the remaining per-window CLI attribution defect; do not merge the whole old branch. The [prior review](CONTRIBUTOR-REVIEW-2026-10-12.md#cli-attribution-findings-in-91) records stale/ambiguous scan evidence, shared terminal process concerns and missing canonical test registration. A scoped follow-up needs those resolved and matching source/backend acceptance. |
| [#93](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/93), @luinbytes: Qt drag-axis namespace | Keep open as a narrow existing-user correctness fix. Main still imports DockDrag.js as Drag, shadowing Qt's axis enum. The PR reports a focused 14/0 QtTest result and user success, but exact-build XPS acceptance and merge authorization remain outstanding. It is not included in v0.1.7. |
| [#71](https://github.com/tcballard/omarchy-plugin-familiar-desktop/pull/71), @Vdcds: Shortcut Coach | Close as out of retirement scope, not on quality grounds. Preserve the PR, branch and author credit for independent reuse or an upstream proposal. No upstream acceptance or transfer is implied. |

Security fixes already shipped remain important: bounded clipboard handling in
v0.1.6 and rejection of foreign app-ID/network icon sources in v0.1.7. Retirement
does not justify reverting them or recommending an older vulnerable release.
Thanks also to @HANCORE-linux for security review and @k-kostin for ARM development
support; the [release acknowledgements](v0.1.6.md#thanks) remain unchanged.

## Issue triage

- Close #87 as superseded by retirement, retaining the original split plan as
  historical context. No v0.2.0 or Windows successor is promised.
- Close the feature tracker #46 and enhancements #48–#62, #64–#65 as not planned.
  These are not marked implemented. Ideas can inform separate Core proposals or
  independent forks after checking upstream scope; no automatic transfer occurs.
- Close #95's stable ARM expansion plan as not planned. Existing ARM source and
  development artifacts remain; no stable ARM desktop acceptance is claimed.
- Keep #63 (display/reveal/popup validation), #74 (renderer ownership/migration),
  #88 (incorrect badge clearing) and #94 (Core bar compatibility) open. They
  concern existing behaviour, unresolved bugs or transition safety. #94 has no
  reproduced regression yet. Retention promises neither work nor a release.
- #74's official integration shipped in v0.1.6; its old v0.1.4 target is obsolete.
  Retain it for residual ownership/removal and changing-host compatibility,
  rather than removing the private fallback for users whose Core is not ready.

## Preservation and any later archive decision

Keep this repository writable for the retained reports and contributions. Do not
archive it as part of this transition, delete source/history/releases, rewrite
contributor attribution, or silently retire binaries still used for recovery.
The MIT licence remains in force; forks must retain its notices and identify
independent ownership, support and plugin identities to avoid installation clashes.

Any later archive decision must first account for outstanding contributors,
known security/removal problems, existing installer/download dependencies and
migration guidance, and be explicitly authorized. Historical release notes and
plans remain dated records, not current promises. This document and the EOL guide
supersede their forward-looking statements.
