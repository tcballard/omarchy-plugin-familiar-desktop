import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: menuWindow
    required property var interaction
    required property var placement
    required property var appearance
    required property bool revealed
    required property var icons
    required property var dockWindow
    property alias menuCard: menuCard
    signal hoverChanged(bool hovered)
    signal iconChosen(string folderId, string icon)
    signal dissolveRequested(string folderId)

    visible: !!interaction.folderMenu && revealed
    screen: dockWindow ? dockWindow.screen : null
    WlrLayershell.namespace: "omarchy-dock-menu"
    WlrLayershell.layer: placement.overlay ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: placement.ignoreExclusion ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    mask: Region { item: menuCard }

    anchors {
        top: placement.anchors.top
        bottom: placement.anchors.bottom
        left: placement.anchors.left
        right: placement.anchors.right
    }
    margins {
        top: placement.margins.top
        bottom: placement.margins.bottom
        left: placement.margins.left
        right: placement.margins.right
    }
    implicitWidth: placement.vertical ? menuCard.width : (dockWindow && dockWindow.screen ? dockWindow.screen.width : 1920)
    implicitHeight: placement.vertical ? (dockWindow && dockWindow.screen ? dockWindow.screen.height : 1080) : menuCard.height

    onVisibleChanged: if (visible) {
        menuCard.resetSelection()
        menuCard.forceActiveFocus()
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: menuWindow.interaction.dismissFolderMenu()
    }
    FolderIconPicker {
        id: menuCard
        anchors.centerIn: parent
        folder: menuWindow.interaction.folderMenu
        icons: menuWindow.icons
        vertical: menuWindow.placement.vertical
        transparent: menuWindow.appearance.transparent
        rounding: menuWindow.appearance.rounding
        borderSpec: menuWindow.appearance.borderSpec
        borderOverlay: DockBorderOverlay {
            radius: Math.min(10, menuWindow.appearance.rounding)
            borderSpec: menuWindow.appearance.borderSpec
            animated: menuWindow.appearance.borderAnimated
            animationDuration: menuWindow.appearance.borderAnimationDuration
        }
        onHoverChanged: function(hovered) { menuWindow.hoverChanged(hovered) }
        onIconChosen: function(icon) { if (folder) menuWindow.iconChosen(folder.id, icon) }
        onDissolveRequested: if (folder) menuWindow.dissolveRequested(folder.id)
        onDismissRequested: menuWindow.interaction.dismissFolderMenu()
    }
}
