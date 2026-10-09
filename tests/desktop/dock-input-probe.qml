import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: panel
        property bool slidOut: true
        anchors.bottom: true
        margins.bottom: 100
        implicitWidth: 800
        implicitHeight: 72
        color: "transparent"
        WlrLayershell.namespace: "familiar-input-probe"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        mask: DockInputRegion {
            surface: card
            translationY: slide.y
            hidden: panel.slidOut
        }
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 400
            height: 68
            color: "#445566"
            transform: Translate {
                id: slide
                y: panel.slidOut ? 56 : 0
                Behavior on y { NumberAnimation { duration: 250 } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: console.log("FAMILIAR_INPUT_HOVER")
                onClicked: console.log("FAMILIAR_INPUT_CLICK")
            }
        }
        Timer {
            interval: 500
            running: true
            onTriggered: panel.slidOut = false
        }
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: Qt.quit()
    }
}
