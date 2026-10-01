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
  property real contentWidth: Style.space(410)
  property real contentHeight: 0
  default property alias contents: contentHolder.data
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
      scroller.contentY = 0
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

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.max(0, Math.min(root.contentWidth + root.padding * 2, parent.width - root.padding * 2))
      height: Math.max(0, Math.min(root.contentHeight + header.height + root.padding * 3, parent.height - root.padding * 2))
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: Math.max(1, Style.space(2))
      border.color: Color.accent

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => { wheel.accepted = true }
      }

      RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.padding }
        spacing: Style.space(8)
        Text {
          text: "󰟀  Familiar Desktop"
          textFormat: Text.PlainText
          font.family: Style.font.family
          font.pixelSize: Style.space(13)
          font.bold: true
          color: Color.popups.text
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
        Rectangle {
          id: closeButton
          implicitWidth: Style.space(32)
          implicitHeight: Style.space(32)
          radius: Style.space(6)
          color: closeMouse.containsMouse || activeFocus ? Color.accent : "transparent"
          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: "Close settings"
          Accessible.onPressAction: root.dismiss()
          Keys.onReturnPressed: root.dismiss()
          Keys.onSpacePressed: root.dismiss()
          Text {
            anchors.centerIn: parent
            text: "×"
            color: Color.popups.text
            font.pixelSize: Style.space(22)
          }
          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismiss()
          }
        }
      }

      Flickable {
        id: scroller
        anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: root.padding }
        clip: true
        contentWidth: width
        contentHeight: root.contentHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Item {
          id: contentHolder
          width: scroller.width
          height: root.contentHeight
        }
      }
    }
  }
}
