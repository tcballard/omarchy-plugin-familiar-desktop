import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root
    property var tools: null
    spacing: 8
    Text {
        Layout.fillWidth: true
        text: "Click an icon to open or return to an app. Right-click for named windows and actions. Close affects one window; Quit requests closing the app’s windows. Force quit stops its process and can lose unsaved work."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Color.popups.text
    }
    Repeater {
        model: [{key: "store", label: "OmaStore"}, {key: "task-manager", label: "Task Manager"}, {key: "settings", label: "System settings"}, {key: "help", label: "Troubleshooting ↗"}]
        delegate: ActionButton {
            required property var modelData
            readonly property bool installed: root.tools && root.tools.tools.some(function(t) { return t.key === modelData.key && t.available })
            Layout.fillWidth: true
            text: modelData.label + (installed ? "" : " · unavailable")
            enabled: installed && !root.tools.busy
            onClicked: root.tools.run(["open-tool", modelData.key])
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Companion apps must be installed separately. Super is the Windows or Command key. These shortcuts come from your running Hyprland configuration; Familiar does not replace your bindings."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 11
        color: Color.popups.text
    }
    TextInput {
        id: filter
        Layout.fillWidth: true
        Layout.minimumHeight: 36
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: 12
        selectByMouse: true
        clip: true
        Accessible.name: "Filter active shortcuts"
        Text {
            visible: !filter.text && !filter.activeFocus
            text: "Search active shortcuts…"
            color: Color.muted
            font: filter.font
        }
    }
    Repeater {
        model: root.tools ? root.tools.shortcuts : []
        delegate: Text {
            required property var modelData
            Layout.fillWidth: true
            visible: !filter.text || (modelData.keys + " " + modelData.description).toLowerCase().indexOf(filter.text.toLowerCase()) >= 0
            text: modelData.keys + " — " + modelData.description + (modelData.submap ? " [" + modelData.submap + "]" : "")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: 12
            color: Color.popups.text
        }
    }
    Text {
        visible: !!root.tools && !root.tools.busy && root.tools.shortcuts.length === 0
        text: "No described shortcuts were returned."
        textFormat: Text.PlainText
        color: Color.popups.text
    }
}
