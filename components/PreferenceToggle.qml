import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons

// A controlled preference: display the owner's value and emit one requested
// value for every mouse, keyboard or accessibility activation.
Rectangle {
    id: control
    required property string label
    property string description: ""
    required property bool checked
    signal toggled(bool value)
    function requestToggle() { if (enabled) toggled(!checked) }

    implicitHeight: 42
    radius: 8
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.description: description
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: requestToggle()
    Keys.onSpacePressed: event => { event.accepted = true; requestToggle() }
    Keys.onReturnPressed: event => { event.accepted = true; requestToggle() }
    border.width: activeFocus ? 2 : 0
    border.color: Commons.Color.accent
    color: mouse.containsMouse ? Commons.Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: control.label
                textFormat: Text.PlainText
                font.family: Commons.Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Commons.Color.popups.text
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: control.description
                textFormat: Text.PlainText
                font.family: Commons.Style.font.family
                font.pixelSize: 10
                color: Commons.Color.muted
                elide: Text.ElideRight
            }
        }
        Rectangle {
            id: track
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: 36
            Layout.minimumWidth: 36
            Layout.maximumWidth: 36
            Layout.preferredHeight: 20
            radius: 10
            color: control.checked ? Commons.Color.accent : Qt.rgba(Commons.Color.popups.text.r, Commons.Color.popups.text.g, Commons.Color.popups.text.b, 0.25)
            Behavior on color { ColorAnimation { duration: 180 } }
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: control.checked ? track.width - width - 3 : 3
                color: control.checked ? Commons.Color.background : Commons.Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.requestToggle()
    }
}
