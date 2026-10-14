# End-of-life transition and migration

Decision: 13 October 2026. Guidance reviewed: 14 October 2026.

I’ve ended feature development on Familiar. v0.1.7 remains available, including
its icon-loading security fix; I’m not promising another release. See
[maintenance policy](MAINTENANCE.md). This notice does not change installed code.

## Check Core availability first

Omarchy has incorporated much of the mouse-friendly desktop path into Core's
Quattro development: a dock for floating workspaces, app launching, minimisation
and window cycling, with titlebars integrated into the floating workspace flow.
This does not establish availability in stable Omarchy, parity with every
Familiar feature, or automatic import of Familiar settings.

Record `omarchy-version` and `hyprctl version` and check your configured channel
against [Omarchy's release notes](https://github.com/omacom/omarchy/releases).
Verify the dock, window restoration and controls on your installed version.
Do not switch channels, install a titlebar package from another channel, force
an ABI mismatch or load a second Hyprbars renderer just to follow this guide.
If Core lacks what you need, keeping the existing installation temporarily is
an option, with no assurance of compatibility after future system updates.

## Before changing anything

1. Save work. Restore Show Desktop and all minimised windows using Familiar's
   dock while it is still active. Keep a terminal available for recovery.
2. Record the installed Familiar commit and helper version:

   ```bash
   git -C "$HOME/.config/omarchy/plugins/io.github.tcballard.familiar-desktop" rev-parse HEAD
   "$HOME/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop" --version
   ```

3. Back up the installed plugin directory (including its matching `bin` files),
   Familiar settings/pins, and your Hyprland and Omarchy configuration. Also retain
   Familiar recovery state under `${XDG_STATE_HOME:-$HOME/.local/state}`.
   Typical settings are `~/.config/omarchy/familiar-desktop-settings.json`,
   `~/.config/omarchy/familiar-desktop-pinned.json` and
   `~/.local/state/omarchy/familiar-desktop-badges.json`. Native helpers also use
   XDG configuration/state paths; see [ownership details](ROLLBACK.md).
   Copy backups to a separate location; do not overwrite your only recovery copy.
4. If this is a development install, retain its source-bound bundle, receipt and
   printed snapshot path. Follow [development rollback](DEVELOPMENT.md) rather
   than mixing release source with development binaries.

The commands below describe the current v0.1.7 helper/script. Older or incomplete
installations may lack commands or fixes. If a command is missing or rejects the
installation, stop and use matching release recovery; do not run a new checkout's
uninstaller against an older installation or bypass ownership checks.

## Disable first, keeping a way back

Disabling is useful for trying Core before deleting Familiar. It retains source,
binaries and preferences. It does **not** reset all input, gesture or window-mode
configuration.

While Familiar still works, use **Use configuration** for any native preferences
you want Core/personal configuration to own: Caps Lock, Command editing shortcuts,
border resizing, trackpad gestures and new-window mode. On official-titlebar
hosts, choosing **Omarchy** in Window controls restores Core's defaults.

Then run this guarded sequence in your normal graphical session:

```bash
(
  set -e
  helper="$HOME/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop"
  "$helper" desktop prepare-remove
  "$helper" taskbar reset
  "$helper" titlebars disable
  omarchy plugin disable io.github.tcballard.familiar-desktop
)
```

`desktop prepare-remove` restores this session's journalled Show Desktop windows
and refuses if hidden/minimised windows remain. Restore those through the dock
and retry. Do not use force-close or delete recovery state to get past this check.
`taskbar reset` reverses Familiar-owned bar changes while preserving later edits;
`titlebars disable` turns off Familiar controls and restores Core defaults on
official hosts. The subshell stops at the first failure; earlier steps may already
have completed. Review the error before continuing.

With Familiar disabled, use Core's controls as documented for your actual
Omarchy version. Recreate pins and layout manually; no automatic importer is
provided or assumed. Verify launch, focus, minimise/restore, titlebar buttons,
bar placement, keyboard/trackpad preferences and `hyprctl configerrors` before
removing Familiar. Avoid running both docks or control integrations together.

If you need Familiar back, first turn off the conflicting Core dock through your
version's documented controls, then:

```bash
omarchy plugin enable io.github.tcballard.familiar-desktop
```

Re-select only the Familiar settings you want; native resets and taskbar resets
are not undone merely by enabling the plugin. Do not reload a private titlebar
library alongside Core's renderer. Moving from the private renderer to the
official integration requires logout/login; save work first and follow
[TITLEBAR-MIGRATION.md](TITLEBAR-MIGRATION.md). A system ABI change can prevent
rollback; restoring old plugin files cannot make an incompatible binary safe.

## Uninstall with cleanup

Once you have restored windows and are ready to remove Familiar, run the script
from the installed plugin, as your normal user in the desktop session:

```bash
bash "$HOME/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/uninstall.sh"
```

The current script performs these operations in order:

1. Restore journalled windows and refuse remaining minimised windows.
2. Reset taskbar changes and disable the plugin.
3. Reset Caps Lock, Command editing, border resizing, gestures and window-mode
   overrides; remove Familiar-owned titlebar configuration.
4. Ask Omarchy to remove the plugin only after cleanup succeeds, then remove the
   stale development receipt. Recovery snapshots remain.

It preserves personal configuration and refuses edited/foreign hooks or failed
reloads instead of guessing. Official titlebar packages and Core-owned renderers
must remain owned by Core; do not uninstall them as part of Familiar cleanup.
Private bundled files disappear with the plugin directory after owned cleanup.
This is not a full desktop snapshot restore and does not reconstruct old window
geometry or tiling order.

Preferences, pins, badge data and recovery backups remain. Keep them until you
have verified the new setup. They are not imported into Core automatically.

## If removal or migration fails

Stop and preserve the error, installed commit and matching helper. Earlier
cleanup steps may already be complete and the plugin may be disabled. Fix the
reported condition and rerun the installed script. Do not run generic plugin
removal, delete the directory, remove shared packages or overwrite whole config
files with old backups to bypass a refusal.

If source/helper files were already deleted, recover the same source and matching
binaries from your backup or the [existing release assets](https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases)
before cleanup. The repository's `install.sh` is a CI template; use the generated
installer asset for the selected release if recovery requires installation.
Compatibility and checksum checks still apply. If recovery cannot pass them,
leave the files/configuration for targeted review and report the failure with
private data removed. I can’t guarantee a support turnaround.

See [troubleshooting](TROUBLESHOOTING.md) and [configuration rollback](ROLLBACK.md).
After successful removal, check visible windows, bar placement, input behaviour
and `hyprctl configerrors`. Save work before any required logout/login.
