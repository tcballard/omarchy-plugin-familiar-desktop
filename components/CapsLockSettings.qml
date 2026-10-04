import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
    id: root
    property var controller: null
    spacing: 6
    Text {
        Layout.fillWidth: true
        text: "Caps Lock behaviour"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: 13
        color: Color.popups.text
    }
    Repeater {
        model: [
            {key: "normal", label: "Normal Caps Lock · capitals on/off"},
            {key: "compose", label: "Compose key · special characters"},
            {key: "reset", label: "Use configuration"}
        ]
        delegate: ActionButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            selected: !!root.controller && root.controller.mode === modelData.key
            enabled: !!root.controller && !root.controller.busy
            onClicked: root.controller.run(modelData.key)
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Changes only when selected. Keeps AltGr and other keyboard options. Per-device overrides still apply. Use configuration removes Familiar’s preference."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Color.popups.text
    }
    Text {
        Layout.fillWidth: true
        text: !root.controller ? "Familiar service is unavailable." : root.controller.busy ? "Applying…" : root.controller.message
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Color.popups.text
    }
    ActionButton {
        text: "Refresh keyboard preference"
        enabled: !!root.controller && !root.controller.busy
        onClicked: root.controller.run("status")
    }
}
