import QtQuick

PreferenceSection {
    id: root
    title: "Caps Lock behaviour"
    choices: [
        {key: "normal", label: "Normal Caps Lock · capitals on/off"},
        {key: "compose", label: "Compose key · special characters"},
        {key: "reset", label: "Use configuration"}
    ]
    explanation: "Changes only when selected. Keeps AltGr and other keyboard options. Per-device overrides still apply. Use configuration removes Familiar’s preference."
    refreshLabel: "Refresh keyboard preference"
}
