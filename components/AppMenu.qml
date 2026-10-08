import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../DockModel.js" as DockModel

// A named, mouse-first window list. It uses the same output and layer as the
// dock, and only the card accepts pointer input outside the dock itself.
PanelWindow {
    id: menu
    required property var root
    required property var dockWindow
    readonly property var app: root.contextApp
    readonly property var windows: app && app.toplevels ? app.toplevels : []
    readonly property int rowHeight: 44
    readonly property int cardWidth: 300
    readonly property int actionHeight: 40
    readonly property int visibleWindowCount: Math.min(8, windows.length)
    property string selectedWindowAddress: ""
    property bool showArrange: false
    property string forceQuitAddress: ""
    readonly property int selectedIndex: {
        for (var i = 0; i < windows.length; i++) {
            if (selectedWindowAddress && root.targetWindowArg(app, i) === selectedWindowAddress) return i
        }
        return -1
    }
    readonly property string selectedAddress: selectedIndex >= 0 ? root.targetWindowArg(app, selectedIndex) : ""
    readonly property bool canAct: selectedAddress !== "" && !root.desktopActionBusy && !root.desktopTools.busy
    readonly property var actions: [
        {label: "Go to / restore selected window", kind: "go-window", enabled: canAct},
        {label: "Bring selected window here", kind: "bring-here", enabled: canAct},
        {label: showArrange ? "Hide arrangement actions ▴" : "Arrange selected window ▾", kind: "arrange", enabled: canAct}
    ].concat(showArrange ? [
        {label: "Left half (floating)", kind: "arrange-left", enabled: canAct},
        {label: "Right half (floating)", kind: "arrange-right", enabled: canAct},
        {label: "Maximise", kind: "arrange-maximize", enabled: canAct},
        {label: "Centre (floating)", kind: "arrange-center", enabled: canAct},
        {label: "Make floating", kind: "arrange-float", enabled: canAct},
        {label: "Return to tiling", kind: "arrange-tile", enabled: canAct},
        {label: "Move to next monitor", kind: "arrange-next-monitor", enabled: canAct}
    ] : []).concat([
        {label: "New Window", kind: "new", enabled: !root.desktopActionBusy && !root.desktopTools.busy},
        {label: app && app.isPinned ? "Unpin from Dock" : "Pin to Dock", kind: "pin", enabled: true},
        {label: "Minimise selected window", kind: "minimize", enabled: canAct},
        {label: "Close selected window", kind: "close", enabled: canAct},
        {label: "Quit app (request close for its windows)", kind: "quit-app", enabled: canAct},
        {label: forceQuitAddress === selectedAddress && forceQuitAddress !== "" ? "Confirm force quit — unsaved work will be lost" : "Force quit app…", kind: "force-quit", enabled: canAct}
    ])
    readonly property int cardHeight: Math.max(80, Math.min(screenHeight - dockOffset - 12, 64 + visibleWindowCount * rowHeight + actions.length * actionHeight + errorLabel.implicitHeight))
    readonly property int dockOffset: root.popupDockOffset
    readonly property real appOffset: (root.hasLeftWidgets ? root.leftWidgetsWidth + root.leftSeparatorSize : 0) +
                                      (root.contextAppIndex + 0.5) * root.slotSize
    readonly property real screenWidth: dockWindow && dockWindow.screen ? dockWindow.screen.width : 1920
    readonly property real screenHeight: dockWindow && dockWindow.screen ? dockWindow.screen.height : 1080

    screen: dockWindow ? dockWindow.screen : null
    visible: !!app && root.dockRevealed && root.dockAvailable
    WlrLayershell.namespace: "omarchy-dock-app-menu"
    WlrLayershell.layer: root.overlayMode ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: card }

    anchors {
        top: root.barPosition === "bottom" || root.isVertical
        bottom: root.barPosition === "top" || root.isVertical
        left: root.barPosition === "right" || !root.isVertical
        right: root.barPosition === "left" || !root.isVertical
    }
    margins {
        top: root.barPosition === "bottom" ? dockOffset : 0
        bottom: root.barPosition === "top" ? dockOffset : 0
        left: root.barPosition === "right" ? dockOffset : 0
        right: root.barPosition === "left" ? dockOffset : 0
    }
    implicitWidth: root.isVertical ? cardWidth : screenWidth
    implicitHeight: root.isVertical ? screenHeight : cardHeight

    onVisibleChanged: if (visible) {
        selectedWindowAddress = windows.length ? root.targetWindowArg(app, Math.min(app.activeTopIndex || 0, windows.length - 1)) : ""
        showArrange = false
        forceQuitAddress = ""
        card.forceActiveFocus()
    }

    onSelectedWindowAddressChanged: forceQuitAddress = ""

    function dismiss() { root.contextAppId = ""; root.contextAppIndex = -1 }
    function chooseWindow(index) {
        root.restoreOrLaunchItem(app, index)
        dismiss()
    }
    function action(kind) {
        if (!app) return
        if (kind === "arrange") { showArrange = !showArrange; return }
        if (kind === "go-window" || kind === "bring-here" || kind.indexOf("arrange-") === 0) {
            if (canAct) root.desktopAction(kind, selectedAddress)
            return
        }
        if (kind === "quit-app") { root.desktopTools.run(["quit-app", selectedAddress]); return }
        if (kind === "force-quit") {
            if (forceQuitAddress !== selectedAddress) { forceQuitAddress = selectedAddress; return }
            root.desktopTools.run(["force-quit", selectedAddress, "--confirm"])
            forceQuitAddress = ""
            return
        }
        if (kind === "new") {
            DockModel.setPendingCliHint(app.appId || app.desktopId || "", root.knownWindows)
            DockModel.launchApp(root.shell, app, Util)
        } else if (kind === "pin") {
            root.setPinned(DockModel.togglePinned(root.pinnedIds, app.appId, root.maxDockItems))
        } else if (kind === "minimize") {
            root.minimizeItem(app, selectedIndex)
        } else if (kind === "close") {
            var index = selectedIndex
            if (windows[index] && typeof windows[index].close === "function") windows[index].close()
        }
        dismiss()
    }

    Rectangle {
        id: card
        width: menu.cardWidth
        height: menu.cardHeight
        x: menu.root.isVertical
            ? 0
            : Math.max(6, Math.min(menu.width - width - 6,
                (menu.root.taskbarActive ? menu.root.taskbarAnchorX : (menu.width - menu.root.totalDockDimension) / 2 + menu.appOffset) - width / 2))
        y: menu.root.isVertical
            ? Math.max(6, Math.min(menu.height - height - 6,
                (menu.height - menu.root.totalDockDimension) / 2 + menu.appOffset - height / 2))
            : 0
        radius: Math.min(12, menu.root.systemRounding)
        color: Color.popups.background
        border.width: Math.max(1, menu.root.systemBorderSize)
        border.color: Color.popups.border
        focus: true
        Keys.onEscapePressed: function(event) { menu.dismiss(); event.accepted = true }

        Flickable {
            anchors.fill: parent
            anchors.margins: 7
            clip: true
            contentWidth: width
            contentHeight: menuContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        Column {
            id: menuContent
            width: parent.width
            spacing: 0

            Text {
                width: parent.width
                height: 40
                leftPadding: 9
                verticalAlignment: Text.AlignVCenter
                text: menu.app ? (menu.app.name || menu.app.appId) + " · " + menu.windows.length + " windows" : ""
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 14
                font.bold: true
                color: Color.popups.text
            }

            Flickable {
                width: parent.width
                height: menu.visibleWindowCount * menu.rowHeight
                contentWidth: width
                contentHeight: menu.windows.length * menu.rowHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    width: parent.width
                    Repeater {
                        model: menu.windows
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: parent.width
                            height: menu.rowHeight
                            radius: 6
                            activeFocusOnTab: true
                            Keys.onReturnPressed: menu.selectedWindowAddress = menu.root.targetWindowArg(menu.app, index)
                            Keys.onSpacePressed: menu.selectedWindowAddress = menu.root.targetWindowArg(menu.app, index)
                            color: activeFocus || windowMouse.containsMouse || menu.selectedIndex === index ? Color.accent : "transparent"
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: (menu.app && menu.app.isActive && menu.app.activeTopIndex === index ? "●  " : "    ") +
                                      (modelData.title || menu.app.name || "Untitled window") + "\n" + menu.root.windowLocation(modelData)
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                font.family: Style.font.family
                                font.pixelSize: 12
                                color: activeFocus || windowMouse.containsMouse || menu.selectedIndex === index ? Color.popups.background : Color.popups.text
                            }
                            MouseArea {
                                id: windowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: menu.selectedWindowAddress = menu.root.targetWindowArg(menu.app, index)
                            }
                        }
                    }
                }
            }
            Text {
                id: errorLabel
                width: parent.width
                text: menu.root.desktopTools.message || menu.root.desktopActionError || (menu.windows.length ? "Select a window above, then choose an action." : "No open windows.")
                wrapMode: Text.WordWrap
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: 11
            }
            Rectangle { width: parent.width; height: 1; color: Color.popups.border }
            Repeater {
                model: menu.actions
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: menu.actionHeight
                    radius: 6
                    activeFocusOnTab: modelData.enabled
                    Keys.onReturnPressed: if (modelData.enabled) menu.action(modelData.kind)
                    Keys.onSpacePressed: if (modelData.enabled) menu.action(modelData.kind)
                    color: actionMouse.containsMouse && modelData.enabled ? Color.accent : "transparent"
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.label
                        wrapMode: Text.WordWrap
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 10
                        textFormat: Text.PlainText
                        font.family: Style.font.family
                        font.pixelSize: 12
                        color: !modelData.enabled ? Color.popups.text :
                               actionMouse.containsMouse ? Color.popups.background : Color.popups.text
                        opacity: modelData.enabled ? 1 : 0.45
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        enabled: modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.action(modelData.kind)
                    }
                }
            }
        }
    }
    }
}
