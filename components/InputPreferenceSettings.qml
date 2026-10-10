import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
ColumnLayout {
    id: root
    property var controller: null
    required property string title
    required property string explanation
    required property string enableLabel
    spacing: 6
    Text {
        Layout.fillWidth: true
        text: root.title
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: 13
        color: Commons.Color.popups.text
    }
    Text {
        Layout.fillWidth: true
        text: root.explanation
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Commons.Color.popups.text
    }
    ActionButton {
        Layout.fillWidth: true
        text: root.enableLabel
        selected: !!root.controller && root.controller.mode === "enable"
        enabled: !!root.controller && !root.controller.busy
        onClicked: root.controller.run("enable")
    }
    ActionButton {
        Layout.fillWidth: true
        text: "Use configuration"
        selected: !!root.controller && root.controller.mode === "reset"
        enabled: !!root.controller && !root.controller.busy
        onClicked: root.controller.run("reset")
    }
    Text {
        Layout.fillWidth: true
        text: !root.controller ? "Familiar service is unavailable." : root.controller.busy ? "Applying…" : root.controller.message
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Commons.Color.popups.text
    }
}
