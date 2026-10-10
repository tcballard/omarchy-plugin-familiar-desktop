import QtQuick
import "../ShortcutLabels.js" as ShortcutLabels

PreferenceSection {
    id: root
    property string labelStyle: "standard"
    title: "Desktop mode"
    choices: [
        {key: "floating", label: "Floating · mouse-friendly overlapping windows"},
        {key: "tiling", label: "Tiling · let Hyprland arrange windows"},
        {key: "reset", label: "Use configuration"}
    ]
    explanation: "Switches existing windows across regular workspaces and sets the layout for new windows, including " + ShortcutLabels.format("Super + Enter", root.labelStyle) + " terminals. Fullscreen, pinned, grouped and hidden windows are skipped. Tiling uses your existing Hyprland layout and keybindings. Use configuration removes the new-window override without moving existing windows."
    refreshLabel: "Refresh window preference"
}
