# Theme-controlled window title bars

This is Familiar Desktop's plugin-owned contract, not an Omarchy shell.toml
section. Add `familiar-desktop.json` to an Omarchy theme root, alongside
`colors.toml`. Choose **Window controls → Theme** in Familiar's settings.
The title-bar dependency must already be set up; changing themes never installs
software or runs a theme-supplied command.

```json
{
  "schemaVersion": 1,
  "titlebars": {
    "enabled": true,
    "style": "mac",
    "height": 36,
    "fontSize": 15,
    "buttonSize": 18,
    "closeColour": "#ff605c",
    "minimizeColour": "#ffbd44",
    "maximizeColour": "#00ca4e",
    "exclusions": ["org.gnome.Nautilus"]
  }
}
```

Theme mode follows the active theme's enablement and layout. Without the file
or an enabled declaration, title bars are off. A new installation defaults to
Theme mode; explicit preferences from the earlier implementation migrate to
Off/Mac/Windows. Mac/Windows force enablement and button placement while still
using theme colours, font and geometry. Off always disables bars, even if the
theme file is malformed. Theme and user exclusions are merged and deduplicated.
The installer intentionally selects its requested Mac/Windows style; select
Theme in settings to delegate enablement and layout afterwards.

| Key | Default | Accepted values |
| --- | --- | --- |
| `enabled` | `false` | Boolean |
| `style` | `windows` | `mac`, `windows` |
| `height` | 34 | Integer 24–80 |
| `fontFamily` | Active shell font family | Plain font name, 1–200 characters |
| `fontSize` | Active shell subtitle size | Integer 8–32 |
| `textAlign` | `center` | `left`, `center` |
| `buttonSize` | 18 | Integer 12–36 |
| `edgePadding` | 10 | Integer 0–40 |
| `buttonPadding` | 9 | Integer 2–30 |
| `background` | Active shell background | `#RRGGBB` |
| `foreground` | Active shell text | `#RRGGBB` |
| `buttonForeground` | `#ffffff` | `#RRGGBB` |
| `closeColour` | `#ff605c` | `#RRGGBB` |
| `minimizeColour` | Mac: `#ffbd44`; Windows: `#646d7e` | `#RRGGBB` |
| `maximizeColour` | Mac: `#00ca4e`; Windows: `#646d7e` | `#RRGGBB` |
| `exclusions` | Empty list | Exact window classes |

Dimensions use Hyprbars' configuration units; the compositor handles display
scale. Height must exceed text and button size by at least four. There may be at
most 32 merged exclusions, each a nonempty class of up to 200 characters. Unknown
titlebar keys, unsupported schema versions and invalid values are rejected with
a status message and controls disabled. The theme cannot replace button actions.

The service watches the active theme name and this file. Theme colour/font token
changes also queue a refresh. Requests are serialized, obsolete completions are
ignored and identical rendered configuration does not trigger another reload.
Familiar's own theme includes Windows defaults. Desktop verification and visual
tuning remain required; portable tests cover policy, migration and generated Lua.
