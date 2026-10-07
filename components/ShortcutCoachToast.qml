import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Only this small surface accepts pointer input. It has no focus grab, scrim,
// exclusive zone, keyboard capture or popup coordinator ownership.
PanelWindow {
    id: root
    required property var controller
    property real topInset: Style.space(16)
    property real leftInset: Style.space(16)
    visible: !!controller.activeLesson
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "familiar-desktop-shortcut-coach"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true }
    margins { top: root.topInset; left: root.leftInset }
    implicitWidth: Math.min(Style.space(360), screen ? screen.width - Style.space(32) : Style.space(360))
    implicitHeight: card.implicitHeight
    mask: Region { item: card }
    ShortcutCoachCard { id: card; anchors.fill: parent; controller: root.controller }
}
