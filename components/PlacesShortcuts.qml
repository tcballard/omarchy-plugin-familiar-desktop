import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
Item {
    id: root
    property bool vertical: false
    property real slotSize: 48
    property bool busy: false
    property string errorText: ""
    signal openLocation(string location)
    width: vertical ? slotSize : 3 * slotSize
    height: vertical ? 3 * slotSize : slotSize
    Repeater {
        model: [ {id: "home", label: "Home", icon: "⌂"}, {id: "downloads", label: "Downloads", icon: "↓"}, {id: "trash", label: "Bin", icon: "󰩺"} ]
        delegate: Rectangle {
            required property var modelData
            required property int index
            x: root.vertical ? 0 : index * root.slotSize
            y: root.vertical ? index * root.slotSize : 0
            width: root.slotSize
            height: root.slotSize
            radius: Style.cornerRadius
            color: mouse.containsMouse || activeFocus ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.15) : "transparent"
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label
            Accessible.onPressAction: if (!root.busy) root.openLocation(modelData.id)
            Keys.onReturnPressed: if (!root.busy) root.openLocation(modelData.id)
            Keys.onSpacePressed: if (!root.busy) root.openLocation(modelData.id)
            Text {
                anchors.centerIn: parent
                text: modelData.icon
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Math.round(root.slotSize * 0.45)
            }
            ToolTip.visible: mouse.containsMouse
            ToolTip.text: root.errorText || modelData.label
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!root.busy) root.openLocation(modelData.id)
            }
        }
    }
}
