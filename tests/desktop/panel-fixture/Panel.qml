import QtQuick
import Quickshell

// Match the real RSS reader's title/app-id without network or preference writes.
Item {
    property var shell: null
    property var manifest: null
    function open(payloadJson) { window.visible = true }
    function close() { window.visible = false }
    FloatingWindow {
        id: window
        visible: false
        title: "RSS Feed"
        implicitWidth: 400
        implicitHeight: 300
        Text { anchors.centerIn: parent; text: "RSS Feed icon fixture" }
    }
}
