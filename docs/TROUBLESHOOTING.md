# Familiar troubleshooting

- **A window disappeared after Show Desktop:** use Restore windows in Familiar settings. If the shell is unavailable, run `~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop desktop restore` from a terminal. Restore before disablement, removal or rollback.
- **Window controls won't load:** the prebuilt library supports the exact Hyprland ABI in the README. Do not rebuild Hyprland or install Cargo. Report the output of `hyprctl version` and Familiar's displayed error.
- **Two title bars:** add the app's exact window class to “Skip apps with their own title bars”.
- **A pinned Foot terminal does not reopen:** older Familiar versions could identify ordinary Foot as Foot Client or Foot Server because those entries share an icon. After upgrading to the fixed version, unpin the incorrect shortcut, open ordinary Foot with `SUPER+Return`, and pin that running terminal again. Close it and click the new pin to check reopening. Existing pins are not automatically rewritten; keep intentionally chosen Foot Client/Server shortcuts.
- **Looking for Paint, Notepad or Task Manager shortcuts:** the curated Open/Install collection is planned for v0.2.0, after package readiness checks. In v0.1.0, launch installed applications through the normal app launcher or dock.
- **Quit leaves the app running:** it sends normal close requests to the selected process's windows. Apps can ask to save or keep a background process. Force quit stops that process and may lose unsaved work; it requires confirmation.
- **Settings or actions stop responding:** record the candidate commit, step, displayed error, Omarchy/Hyprland versions and monitor layout, then use the [XPS checklist](XPS-TEST.md). A shell reload does not erase the recovery journal.

[Report a Familiar bug](https://github.com/tcballard/omarchy-plugin-familiar-desktop/issues).
