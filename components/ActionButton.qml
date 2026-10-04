import QtQuick
import qs.Commons

Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    signal clicked()
    implicitHeight: 40
    implicitWidth: 120
    radius: 7
    color: selected ? Color.accent : (mouse.containsMouse || activeFocus ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent")
    border.width: 1
    border.color: activeFocus ? Color.accent : Color.popups.border
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    Text {
        anchors.fill: parent
        anchors.margins: 8
        text: root.text
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: 12
        color: root.selected ? Color.background : Color.popups.text
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
