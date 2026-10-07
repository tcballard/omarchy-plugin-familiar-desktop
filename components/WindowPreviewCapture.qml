import QtQuick
import Quickshell.Wayland

Item {
    id: root
    property var windowSource: null
    property bool stoppedCapture: false
    readonly property bool hasContent: capture.hasContent
    ScreencopyView {
        id: capture
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        captureSource: root.stoppedCapture ? null : root.windowSource
        live: !root.stoppedCapture
        paintCursor: false
        constraintSize: Qt.size(root.width, root.height)
        onStopped: root.stoppedCapture = true
    }
}
