import QtQuick

PreferenceSection {
    id: root
    title: "Trackpad gestures"
    choices: [
        {key: "all", label: "Workspace and desktop swipes"},
        {key: "workspace", label: "Workspace swipes only"},
        {key: "desktop", label: "Desktop swipes only"},
        {key: "reset", label: "Use configuration"}
    ]
    explanation: "Three fingers left/right switch workspaces. Four fingers down shows the desktop; four fingers up restores windows. Opt-in: detected conflicts restore your previous configuration. Use configuration removes Familiar’s gestures. Two-finger tap uses your system’s right-click setting; scrolling over a running app cycles its windows."
    refreshLabel: "Refresh gesture preference"
}
