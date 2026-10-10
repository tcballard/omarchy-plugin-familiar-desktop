import QtQuick
import qs.Commons
import qs.Commons as Commons
Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    signal clicked()
    implicitHeight: 40
    implicitWidth: Math.max(120, label.implicitWidth + 24)
    radius: 7
    color: selected ? Commons.Color.accent : (mouse.containsMouse || activeFocus ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent")
    border.width: 1
    border.color: activeFocus ? Commons.Color.accent : Commons.Color.popups.border
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    Text {
        id: label
        anchors.fill: parent
        anchors.margins: 8
        text: root.text
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: root.selected ? Commons.Color.background : Commons.Color.popups.text
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
