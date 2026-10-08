import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."
import "../DockModel.js" as DockModel
import "../WindowPreviews.js" as Previews

Item {
    id: root
    property var service: null
    property var bar: null
    readonly property int slotSize: Math.max(24, bar ? bar.barSize : 32)
    readonly property var items: service ? service.dockItems : []
    // Leave the native status widgets room; overflow stays reachable by arrows.
    readonly property real screenWidth: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.width : 1280
    readonly property real capacity: Math.max(slotSize, Math.min(slotSize * 7, Math.floor((screenWidth * 0.22 - 2 * slotSize) / slotSize) * slotSize))
    readonly property bool overflow: items.length * slotSize > capacity
    implicitWidth: Math.min(items.length * slotSize, capacity) + (overflow ? slotSize * 2 : 0)
    implicitHeight: slotSize
    function anchor(item) {
        if (!service) return
        service.taskbarAnchorItem = item
        service.taskbarItemSize = slotSize
    }
    onVisibleChanged: if (!visible) preview.close()
    Component.onCompleted: if (service) service.registerTaskbarHost(root)
    Component.onDestruction: {
        if (service) service.unregisterTaskbarHost(root)
        if (service && service.taskbarAnchorItem && service.taskbarAnchorItem.QsWindow.window === root.QsWindow.window)
            service.taskbarAnchorItem = null
    }
    WindowPreviewController {
        id: preview
        allowed: root.visible && !!root.service && root.service.windowPreviews && !root.service.isEditMode
            && !root.service.isMenuOpen && !root.service.isStackOpen && root.service.contextAppId === ""
        onOpenedChanged: {
            if (!root.bar) return
            if (opened) root.bar.requestPopout(preview)
            else root.bar.releasePopout(preview)
        }
    }
    Loader {
        active: preview.opened
        sourceComponent: WindowPreviewPopup {
            controller: preview
            bar: root.bar
            onWindowSelected: function(target) {
                var index = Previews.currentIndex(preview.app, target)
                if (index >= 0) root.service.restoreOrLaunchItem(preview.app, index)
                preview.close()
            }
        }
    }
    Row {
        anchors.fill: parent
        WidgetButton {
            visible: root.overflow
            bar: root.bar
            text: "‹"
            tooltipText: "Previous taskbar apps"
            implicitWidth: root.slotSize
            implicitHeight: root.slotSize
            onPressed: apps.contentX = Math.max(0, apps.contentX - apps.width)
        }
        Flickable {
            id: apps
            width: Math.min(root.items.length * root.slotSize, root.capacity)
            height: root.slotSize
            contentWidth: root.items.length * root.slotSize
            contentHeight: height
            clip: true
            interactive: root.overflow && !(root.service && root.service.isEditMode)
            boundsBehavior: Flickable.StopAtBounds
            onContentWidthChanged: contentX = Math.max(0, Math.min(contentX, contentWidth - width))
            onMovementStarted: preview.close()
            Row {
                Repeater {
                    model: root.items
                    DockItem {
                        id: app
                        required property var modelData
                        required property int index
                        property var registeredBar: null
                        property bool concealed: app.x < apps.contentX || app.x + app.width > apps.contentX + apps.width
                        function registerClickTarget() {
                            if (registeredBar) registeredBar.unregisterClickTarget(app)
                            registeredBar = root.bar
                            if (registeredBar) registeredBar.registerClickTarget(app)
                        }
                        Component.onCompleted: registerClickTarget()
                        Component.onDestruction: if (registeredBar) registeredBar.unregisterClickTarget(app)
                        Connections { target: root; function onBarChanged() { app.registerClickTarget() } }
                        itemData: modelData
                        itemIndex: index
                        totalCount: root.items.length
                        shell: root.service ? root.service.shell : null
                        barPosition: "top" // DockItem uses the edge opposite the surface.
                        slotSize: root.slotSize
                        iconBaseSize: Math.min(32, root.slotSize - 12)
                        showBadges: root.service ? root.service.showBadges : true
                        iconRevision: root.service ? root.service.iconRevision : 0
                        iconsReady: root.service ? root.service.iconsReady : false
                        isEditMode: root.service ? root.service.isEditMode : false
                        dockDragActiveIndex: root.service ? root.service.dockDragActiveIndex : -1
                        onPreviewHoverChanged: function(item, hovered) {
                            if (hovered) { root.anchor(item); preview.enter(item) }
                            else preview.leave(item)
                        }
                        onPreviewCancelled: preview.close()
                        onRestoreOrLaunchRequested: function(item, targetIndex) { root.service.restoreOrLaunchItem(item, targetIndex) }
                        onMinimizeRequested: function(item, targetIndex) { root.service.minimizeItem(item, targetIndex) }
                        onOriginalAppLaunched: function(appId) { root.service.requestFocusOnLaunch(appId) }
                        onItemLeftClicked: function(item) {
                            root.anchor(app)
                            root.service.contextAppId = ""
                            if (item && item.isStack) root.service.toggleStack(item, index)
                            else { root.service.clearBadge(item); root.service.activeStackItem = null; root.service.activeMenuItem = null }
                        }
                        onItemRightClicked: function(item, target) {
                            root.anchor(app)
                            preview.close()
                            if (root.service.isEditMode) { root.service.isEditMode = false; return }
                            if (item && item.isStack) root.service.toggleMenu(item, index, false)
                            else root.service.toggleAppMenu(item, index)
                        }
                        onEditModeRequested: { root.anchor(app); root.service.isEditMode = true }
                        onEditModeExitRequested: root.service.isEditMode = false
                        onTogglePinRequested: function(id) { root.service.setPinned(DockModel.togglePinned(root.service.pinnedIds, id, root.service.maxDockItems)) }
                        onDissolveRequested: function(id) { root.service.setPinned(DockModel.dissolveStack(root.service.pinnedIds, id)); root.service.isEditMode = false }
                        onDragStarted: function(index) { root.service.dockDragActiveIndex = index }
                        onDragEnded: root.service.dockDragActiveIndex = -1
                        onMoveRequested: function(from, to) { root.service.dockDragActiveIndex = -1; root.service.setPinned(DockModel.reorderPinned(root.service.pinnedIds, root.items, from, to)) }
                        onMergeRequested: function(from, to) { root.service.dockDragActiveIndex = -1; root.service.setPinned(DockModel.mergeIntoStack(root.service.pinnedIds, root.items, from, to, root.service.appRows)) }
                    }
                }
            }
        }
        WidgetButton {
            visible: root.overflow
            bar: root.bar
            text: "›"
            tooltipText: "More taskbar apps"
            implicitWidth: root.slotSize
            implicitHeight: root.slotSize
            onPressed: apps.contentX = Math.min(Math.max(0, apps.contentWidth - apps.width), apps.contentX + apps.width)
        }
    }
}
