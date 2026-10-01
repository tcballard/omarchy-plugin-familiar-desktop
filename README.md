<h1 align="center">Familiar Desktop</h1>

<p align="center">
  <a href="https://github.com/tcballard/omarchy-badges"><img src="https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg" alt="Built for Omarchy: Plugin" height="24"></a>
</p>

**Find your apps and the right window without learning a new desktop first.**

Familiar Desktop adds a mouse-friendly app dock to Omarchy Quattro. Launch or return to an app with a click; right-click to see its open windows by name and choose exactly where to go. General, Windows and Mac starting layouts share your pinned apps, so you can choose what feels comfortable and adjust it later.

![Familiar Desktop running on Omarchy, with the General layout selected, dock settings open and the app dock along the bottom](docs/images/familiar-desktop.png)

*Familiar Desktop on Omarchy: the General starting layout and dock settings.*

## Install

Version **0.0.2 is an early preview** for Omarchy Quattro. Live desktop testing remains outstanding. Run this single command in your Omarchy terminal for Mac-style controls:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tcballard/omarchy-plugin-familiar-desktop/v0.0.2/install.sh) mac
```

Use `windows` instead of `mac` for controls on the right. The same command handles fresh installs and updates, checks out **v0.0.2**, installs missing build tools through pacman, builds the Rust backend and enables the dock and controls. It refuses to overwrite tracked local source changes. Rustup users get the stable toolchain; system Rust must be 1.88 or newer.

Setup first tries to reuse a compatible Hyprbars installation. If that fails, it runs Hyprpm to prepare or update the dependency. **Hyprpm may clone Hyprland to build matching headers and take several minutes; this does not replace your installed compositor.** Package installation may ask for your password. The installer prints five progress stages and stops if a stage fails; rerun the same command after resolving the reported error. An interrupted setup may leave downloaded dependencies or a built plugin, but it does not proceed to enablement after failure.

The shared `bin/familiar-desktop` Rust binary handles window actions, title-bar setup, theme parsing, app/icon scans and badge writes. Downloads, builds and privilege prompts happen in your terminal during explicit setup. The hosted shell never compiles or downloads code.

The plugin adds a **Familiar Desktop** control to the bar. Open it to choose a starting layout and adjust dock settings. If you already use another dock, disable it before enabling this one so the two do not occupy the same edge.

### Dock and window controls together

Optional title bars add a visible window title, close, minimise and maximise
buttons, dragging and double-click to maximise. Mac controls sit on the left;
Windows controls sit on the right. Minimise uses the dock's existing window
helper, so the window can be restored from the same dock. The title is supplied
by the app, rather than a separate desktop-entry app name.

The installer above sets up both the dock and window controls. Hyprbars is a compositor dependency managed by Hyprpm.

If Familiar is already installed, open **Window controls** in its bar settings,
copy the one-time setup command, run it in a terminal, then select **Mac** or
**Windows**, or **Theme**, and press **Refresh window controls**. Theme mode reads
the active theme's [window-control defaults](docs/TITLEBAR-THEMES.md), including
enablement, placement, font, sizes, colours and exclusions. The Familiar theme
provides Windows defaults; themes without an enabled declaration leave bars off.
Explicit Off/Mac/Windows choices take precedence. Existing explicit title-bar
preferences are preserved; otherwise Theme is the default. Layout presets preserve
Theme and Off choices. Enabling controls also enables the dock so
minimised windows have a way back; disabling the dock disables its controls.

Setup needs Omarchy's Lua Hyprland configuration and a compatible Hyprbars build
with Lua button support. It probes compatibility before adding a marked block
to `~/.config/hypr/looknfeel.lua`, preserves the rest of that file and refuses
to adopt a loaded Hyprbars installation belonging to another setup. After a
Hyprland update, rerun setup if controls report a compatibility failure.

Apps that already draw their own header may show two title bars. Enter their
exact Hyprland window classes in **Skip apps with their own title bars**, separated
by commas. Fullscreen, grouped windows and mixed display scales need an on-device
check; this feature has portable test coverage, not live desktop verification.

Switch **Window controls → Off** to disable them. Disabling/unloading Familiar
also requests cleanup; an abrupt shell crash can leave controls active until
the next shell start or explicit cleanup. Before removing Familiar, remove its
configuration hook:

```bash
~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop titlebars remove
```

This removes only Familiar's marked block and generated configuration; it leaves
Hyprbars installed. The generated configuration checks that Familiar's manifest
still exists, so removal prevents bars loading on the next Hyprland reload.

Launching apps uses Omarchy's app launcher, with `uwsm-app` and `gtk-launch` as fallbacks. Supported command-line apps use `foot`; copying the shortcut uses `wl-copy`. Audio controls use `wpctl`. These integrations use the corresponding tools already installed on Omarchy. The plugin reads local app entries, window information, theme settings and notification counts. It launches apps and Omarchy actions when requested; it has no account login or built-in network client.

## Made for everyday use

- **See what is running.** Pinned apps and running windows stay within reach, with indicators and notification badges from the dock implementation.
- **Choose a window by name.** Right-click an app for a scrollable window list, New Window, Pin or Unpin, Minimize Current Window and Close Current Window.
- **Use the mouse or keyboard.** Left-click launches or switches, middle-click opens a new window, and the existing dock supports keyboard selection and window cycling.
- **Keep your setup.** Pins and folders are shared between layouts; changing a preset does not install applications, themes or global shortcuts.

### Choose a layout

| Starting layout | Placement | Visibility | Window space |
| --- | --- | --- | --- |
| **General** | Opposite the Omarchy bar | Always visible | Reserves space |
| **Windows** | Bottom when the bar is elsewhere | Always visible | Reserves space |
| **Mac** | Bottom when the bar is elsewhere | Reveals on hover | Overlays windows |

If your Omarchy bar is already at the bottom, the dock uses the opposite edge to avoid an overlap. The layout names describe starting behavior; this build does not reproduce a complete Windows taskbar or macOS Dock. After selecting a preset, you can change visibility, workspace targeting, badges and widgets individually. Those adjustments remain until you choose another preset.

## Controls

| Action | How |
| --- | --- |
| Launch or switch to an app | Left-click its icon |
| See and select named windows | Right-click its icon, then click a window |
| Open another window | Middle-click its icon or choose **New Window** |
| Pin, unpin, minimize or close | Right-click its icon and choose the action |
| Change layout and settings | Open **Familiar Desktop** in the bar |

For scripting, the preset switch is also available through Omarchy shell IPC:

```bash
omarchy-shell io.github.tcballard.familiar-desktop setProfile general
omarchy-shell io.github.tcballard.familiar-desktop setProfile windows
omarchy-shell io.github.tcballard.familiar-desktop setProfile mac
```

## Update and remove

Rerun the installation command above to install or repair v0.0.2. This checkout stays pinned to its release; use the installer from a newer release when upgrading.

To remove it:

```bash
~/.config/omarchy/plugins/io.github.tcballard.familiar-desktop/bin/familiar-desktop titlebars remove
omarchy plugin remove io.github.tcballard.familiar-desktop
```

The plugin writes `~/.config/omarchy/familiar-desktop-settings.json`, `~/.config/omarchy/familiar-desktop-pinned.json` and `~/.local/state/omarchy/familiar-desktop-badges.json`. Removing it leaves these preferences and badge data in place. Dock widgets appear alongside existing bar widgets. Dock settings only change Familiar Desktop; `shell.json` is read for bar placement and is never written by this plugin. Switching dock widgets off preserves your selection for when you turn them back on. It does not install the [Familiar theme](https://github.com/tcballard/omarchy-theme-familiar), Task Manager or OmaStore.

If you moved bar widgets into the dock using an earlier development build, add them back through Omarchy's bar settings. This build preserves old placement metadata in its settings file but does not automatically rewrite your bar layout.

## Development and status

The manifest declares a hosted service and bar widget under `io.github.tcballard.familiar-desktop`. The source derives from [rosakodu/omarchy-dock](https://github.com/rosakodu/omarchy-dock) at commit `467070386fe60e173295020d3911176202b3e0c9` (MIT). This project has separate identity and settings while retaining that dock's window, monitor, folder and theme handling. See [the product record](PRODUCT.md) for the current scope and next milestones.

Portable plugin validation and the tests in `tests/run` pass. The preview shows an on-device layout, but live checks remain: initial installation, preset switching, menu focus and dismissal, minimized windows, two monitors, workspace changes, light and dark themes, 200% scale, shell reload, dock widget persistence and removal. Version 0.0.2 is an early preview; live desktop and marketplace verification remain outstanding. Report bugs through [GitHub issues](https://github.com/tcballard/omarchy-plugin-familiar-desktop/issues); report sensitive security issues privately through the repository's GitHub security advisory feature.

On Omarchy, validate and test the checkout with:

```bash
omarchy plugin validate .
```

See [validation notes](docs/VALIDATION.md) for automated coverage, the preview source and the remaining desktop checks.

MIT licensed. Original work © 2026 rosakodu; Familiar Desktop changes © 2026 Tom Ballard. See [LICENSE](LICENSE).
