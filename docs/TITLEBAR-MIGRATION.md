# Official titlebar migration — issue #74

Status: preparatory coexistence safeguards, **not a completed migration**.
Checked 8 October 2026. Keep #74 open until the migration and live acceptance
criteria are met. Tom approved including the safeguards with the Windows taskbar
and dock opacity in the v0.1.3 integration candidate on 8 October 2026. The full
official-package migration targets v0.1.4, conditional on the work below.

## Verified upstream contracts

- [Package PR #852](https://github.com/omacom/omarchy-pkgs/pull/852) merged.
  Source inspected at `efc09808c6ce98a243b02796f65dbcafd67f97c6`.
  `omarchy-hyprland-titlebars` 0.1.0-1 was present in the x86_64 **edge** database,
  absent from **rc** and **stable**. This is a dated observation, not a promise
  about later channel availability. Do not switch a user's package channel.
- Package path: `/usr/lib/omarchy-hyprland-titlebars/titlebars.so`.
  PKGBUILD depends on `hyprland=0.56.2`; plugin initialization checks the exact
  Hyprland header/runtime hash. A matching version alone is insufficient.
- [Core PR #14482](https://github.com/omacom/omarchy/pull/14482) remains open;
  inspected head `a417df6634157775805c7da55eb0ed1455a06806`. Core supplies a global
  button list, theme values and workspace scope. Familiar cannot independently
  overwrite these globals while claiming coexistence.
- Hyprland `efb50993780079460b0cbed1363e2166a2de1d9f` exposes name/author/version/
  description in `hl.get_loaded_plugins()` and additionally handle in
  `hyprctl -j plugin list`. Neither exposes the library path or config ownership.
  Both backends identify as hyprbars/Vaxry/1.0. These values are not provenance.
  See `src/debug/HyprCtl.cpp` and
  `src/config/lua/bindings/LuaBindingsToplevel.cpp` in that revision.

## Parity audit

| Behaviour | Official source evidence | Remaining work |
| --- | --- | --- |
| Lua buttons, colours, font, left/right alignment | `main.cpp` registers `add_button` and the corresponding config values | Live Windows/Mac verification |
| Hover-only icons, double click | `icon_on_hover`, `on_double_click` are supported | Preserve user preferences |
| Familiar vector icons | `barDeco.cpp` renders the icon string as font text; it has no Familiar vector renderer | Upstream renderer support or an explicitly accepted visual change; do not pass `familiar-windows-close` as visible text |
| Button targeting | Official actions support `%WINDOW%` | Adapt Familiar actions to accept the clicked address; do not depend on later focus |
| Floating/tiling and Core | `workspace_tag` scopes bars; global options/buttons are shared | Agree on one configuration owner and test Core Shelf/floating workspace interactions |
| Backend identity | Registration metadata is identical; loaded path is not exposed | Obtain verifiable provenance before adopting an already-loaded backend |

## Safeguards in this branch

- Setup refuses **any** already-loaded Hyprbars backend, even with an old
  Familiar owner record. Turn off Familiar controls before rerunning setup.
- Explicit backend paths must resolve inside this installation's private
  `bin/hyprbars` tree. A symlink into a system/hyprpm directory is refused.
- The old `--install-dependency` hyprpm path is refused; no competing backend is
  installed through it.
- Development installation and rollback refuse before any mutation when the
  official library is present, including rollback to older code without guards.
- If the official library is installed, download/setup refuses the bundled
  backend. Reconciliation pauses only Familiar's generated loader and reports
  an actionable message in its existing controls UI. Generated Lua repeats the
  check on compositor reload, before any bundled load or configuration call.
- With that system library present, disable/remove does not send unload or reload
  commands. Remove deletes only the exact owned hook/record/generated file.
  Restart Hyprland to retire an already-running Familiar backend. The system
  package and personal settings are kept.

These checks do not infer arbitrary loaded-backend provenance from its name and
are not a complete solution to another integration dynamically loading a fork.
The old binary may remain mapped until restart. A restart is required after
installing the official package over an existing Familiar titlebar session.
No existing system package is removed or upgraded by these safeguards.

## Migration still required

1. Add a trustworthy loaded-library provenance/ownership contract upstream (or
   another verified mechanism) and a single owner of shared configuration.
2. Resolve the vector/control-action differences above and verify the package
   available in the user's current repository against the running Hyprland ABI.
3. Implement an in-app package installation/migration transaction: preserve
   preferences and owned config, retire only the old private backend, activate
   the official package, and restore the prior state on failure. A package
   installed for Core must remain installed on Familiar removal.
4. Update source-matched development install/rollback receipts, smoke fixtures,
   packaging and release workflows, then remove the redundant bundled build and
   download path. Retained here only for existing supported installations where
   the official package is absent; this is not a new fallback decision.
5. Run migration/failure regressions and an exact-build desktop test covering
   controls, theme/reload/restart, floating/tiling and Core coexistence. Record
   Tom's XPS acceptance separately from CI before promotion.
