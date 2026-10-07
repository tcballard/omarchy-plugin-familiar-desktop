import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons

// The invoking bar selects the monitor only; it never positions the card.
PanelWindow {
  id: root
  required property Item anchorItem
  required property var owner
  required property var bar
  property bool open: false
  property real contentWidth: Style.space(800)
  property alias page: frame.page
  property alias section: frame.section
  function shows(pageKey, sectionKey) { return frame.shows(pageKey, sectionKey) }
  property real contentHeight: 0
  default property alias contents: frame.contents
  readonly property real padding: Style.space(16)

  screen: anchorItem.QsWindow.window ? anchorItem.QsWindow.window.screen : null
  visible: open
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }
  WlrLayershell.namespace: "familiar-desktop-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function dismiss() { owner.close() }
  onOpenChanged: {
    if (open) {
      frame.resetScroll()
      focusScope.forceActiveFocus()
      if (bar) bar.requestPopout(owner)
    } else if (bar && bar.activePopout === owner) {
      bar.releasePopout(owner)
    }
  }
  onBackingWindowVisibleChanged: {
    if (backingWindowVisible && open) focusScope.forceActiveFocus()
  }

  FocusScope {
    id: focusScope
    anchors.fill: parent
    focus: root.open
    Keys.onEscapePressed: event => { root.dismiss(); event.accepted = true }

    Rectangle {
      anchors.fill: parent
      color: "#99000000"
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.dismiss()
        onWheel: wheel => { wheel.accepted = true }
      }
    }

    SettingsFrame {
      id: frame
      anchors.centerIn: parent
      width: Math.max(0, Math.min(root.contentWidth, parent.width - root.padding * 2))
      height: Math.max(0, Math.min(Style.space(560), parent.height - root.padding * 2))
      contentHeight: root.contentHeight
      onDismissed: root.dismiss()
    }
  }
}
