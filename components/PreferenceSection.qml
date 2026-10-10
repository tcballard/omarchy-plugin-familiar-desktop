import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
// A controller owns the selected value and result. This view only requests actions.
ColumnLayout {
    id: section
    property var controller: null
    required property string title
    required property var choices
    required property string explanation
    required property string refreshLabel
    spacing: 6
    Text {
        Layout.fillWidth: true
        text: section.title
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: 13
        color: Commons.Color.popups.text
    }
    Repeater {
        model: section.choices
        delegate: ActionButton {
            required property var modelData
            objectName: "choice-" + modelData.key
            Layout.fillWidth: true
            text: modelData.label
            selected: !!section.controller && section.controller.mode === modelData.key
            enabled: !!section.controller && !section.controller.busy
            onClicked: section.controller.run(modelData.key)
        }
    }
    Text {
        Layout.fillWidth: true
        text: section.explanation
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Commons.Color.popups.text
    }
    Text {
        objectName: "preference-status"
        Layout.fillWidth: true
        text: !section.controller ? "Familiar service is unavailable." : section.controller.busy ? "Applying…" : section.controller.message
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: Commons.Color.popups.text
    }
    ActionButton {
        objectName: "preference-refresh"
        Layout.fillWidth: true
        text: section.refreshLabel
        enabled: !!section.controller && !section.controller.busy
        onClicked: section.controller.run("status")
    }
}
