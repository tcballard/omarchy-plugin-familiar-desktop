# Caps Lock in Familiar

Adapted from the behaviour proposed in [omacom/omarchy#12752](https://github.com/omacom/omarchy/pull/12752).
Familiar owns its separate marked block; it does not install the upstream patch or write its state file.

The setting is opt-in. Choose Normal Caps Lock, Compose key, or Use configuration.
The last removes Familiar’s override and reloads the current configuration, including any upstream preference that may be added later.
Per-device keyboard options still win. Caps-based layout switching and both-Shift Caps Lock options are removed while the override is active; unrelated options, including Right Alt/AltGr and Compose on other keys, are retained.

The Rust helper accepts `caps-lock status|normal|compose|reset`. QML sends literal argument arrays through one shared service controller. Status reads the saved preference, not proof of each physical keyboard’s active map. No keyboard preference is changed at service startup or when a layout preset changes.

Only the exact generated block is replaced/removed. The helper refuses foreign, edited, duplicate or broken blocks, a missing main config and symlinked/nonregular main configs. It preserves file permissions, backs up prior contents privately in the XDG state directory, and checks Hyprland reload, configuration errors and the selected global option. If applying fails, it restores the previous config and attempts a recovery reload. Concurrent external edits encountered during recovery are preserved and require manual comparison with the backup.

The explicit preference survives disabling the Familiar UI and shell reloads. Reset before downgrade/removal:

```bash
~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop caps-lock reset
```

If the helper is unavailable, back up `hyprland.lua`, remove only the block between `-- BEGIN FAMILIAR CAPS LOCK` and `-- END FAMILIAR CAPS LOCK`, then run `hyprctl reload` and inspect `hyprctl configerrors`. Never replace the whole config blindly from an old backup. `input.lua` and Omarchy files remain untouched.

Development tests require Lua (`lua5.4` in CI) to execute the actual generated hook against fixtures. Lua is not added as an installation dependency; Hyprland executes the installed hook itself. CI covers config preservation/reset, errors and rollback, malformed/foreign blocks, absence/symlink refusal, emitted Lua option preservation, repeated loads and removal guard, plus QML serialization/error states. Live tests remain in XPS-TEST.md: native/XWayland typing, Caps/Shift, UK AltGr, Compose sequences, layout switching, per-device overrides, reload and login. Never infer physical keyboard acceptance from these fixtures.
