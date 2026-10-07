import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "../WindowPreviews.js" as Previews

PopupCard {
    id: root
    required property var controller
    signal windowSelected(var target)
    anchorItem: controller.target
    owner: controller
    triggerMode: "hover"
    centerOnBar: false
    open: controller.opened
    property int pageIndex: 0
    readonly property var windows: controller.app ? controller.app.toplevels || [] : []
    readonly property int pageCount: Math.ceil(windows.length / 3)
    onPageCountChanged: pageIndex = Math.min(pageIndex, Math.max(0, pageCount - 1))
    onContainsMouseChanged: controller.popupHovered = containsMouse
    padding: Style.space(10)
    contentWidth: fittedContentWidth(Math.min(3, windows.length) * Style.space(210) + padding * 2)
    contentHeight: fittedContentHeight(body.implicitHeight)

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8)
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Repeater {
                model: root.windows.slice(root.pageIndex * 3, root.pageIndex * 3 + 3)
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property var info: Previews.describe(modelData,
                        ToplevelManager.toplevels.values, Hyprland.toplevels.values)
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: info.title + ", " + info.workspace
                    Accessible.onPressAction: root.windowSelected(modelData)
                    Keys.onReturnPressed: root.windowSelected(modelData)
                    Keys.onSpacePressed: root.windowSelected(modelData)
                    Keys.onEscapePressed: root.controller.close()
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: Style.space(170)
                    radius: Style.space(6)
                    color: Color.popups.background
                    border.width: 1
                    border.color: pointer.containsMouse || activeFocus ? Color.accent : Color.popups.border
                    Item {
                        id: picture
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(6) }
                        height: Style.space(110)
                        clip: true
                        Loader {
                            id: capture
                            anchors.fill: parent
                            active: root.open && !!tile.info.capture
                            source: "WindowPreviewCapture.qml"
                            onLoaded: item.windowSource = Qt.binding(function() { return tile.info.capture })
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: !capture.item || !capture.item.hasContent
                            spacing: Style.space(4)
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Style.space(32); height: width
                                source: Quickshell.iconPath(tile.modelData.appId || "application-x-executable", true)
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                text: "Preview unavailable"
                                textFormat: Text.PlainText
                                color: Color.muted
                                font.pixelSize: Style.space(11)
                            }
                        }
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; top: picture.bottom; margins: Style.space(8) }
                        spacing: Style.space(4)
                        Text {
                            width: parent.width
                            text: tile.info.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.space(12)
                        }
                        Text {
                            width: parent.width
                            text: tile.info.workspace
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Color.muted
                            font.pixelSize: Style.space(11)
                        }
                    }
                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.windowSelected(tile.modelData)
                    }
                }
            }
        }
        RowLayout {
            visible: root.pageCount > 1
            Layout.fillWidth: true
            ActionButton { text: "Previous"; enabled: root.pageIndex > 0; onClicked: root.pageIndex-- }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: (root.pageIndex + 1) + " / " + root.pageCount
                color: Color.popups.text
            }
            ActionButton { text: "Next"; enabled: root.pageIndex + 1 < root.pageCount; onClicked: root.pageIndex++ }
        }
    }
}
