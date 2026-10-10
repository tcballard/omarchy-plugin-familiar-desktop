import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel
import "HostedWidgets.js" as HostedWidgets
import "PluginPanels.js" as PluginPanels
import "IconResolver.js" as Icons
import "DockSettings.js" as DockSettings
import "DockGeometry.js" as Geometry
import "DockDrag.js" as Drag
import "ShortcutLabels.js" as ShortcutLabels
import "DockCommands.js" as DockCommands
import "WindowPreviews.js" as WindowPreviews
import "components"

Item {
    id: root

    // Properties injected by Omarchy Shell host
    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    // Omarchy 4.0.3 scopes pluginRegistry to this plugin's own manifest, so
    // getWidgetSource() can no longer resolve another plugin's entry point.
    // Declaring this makes the host inject the widget-catalogue facade, whose
    // snapshot still carries every registered widget's Component.
    property var barWidgetRegistry: null
    readonly property int widgetRegistryRevision: barWidgetRegistry ? barWidgetRegistry.revision : 0
    onWidgetRegistryRevisionChanged: updateDockItems()

    // Dock state & Multi-source Live Bar Position Tracking
    property bool opened: true
    property bool pluginEnabled: true
    Timer {
        interval: 350
        running: !root.pluginEnabled && taskbarController.mode === "enable" && !taskbarController.busy
        onTriggered: { root.pendingTaskbarProfile = ""; taskbarController.run("reset") }
    }
    readonly property var setup: setupController
    SetupController {
        id: setupController
        active: root.pluginEnabled
        canStart: !titlebars.busy
        onInstalled: function(style) {
            settings.reload()
            if (setupController.applyLayout) root.setProfile(style)
            root.refresh()
            titlebars.refresh()
        }
    }
    SetupWindow {
        controller: setupController
        screen: root.effectiveDockScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null)
    }
    property string shellConfigPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    property string detectedBarPosition: {
        if (shell && shell.barConfig && shell.barConfig.position) return shell.barConfig.position
        return "top"
    }
    property bool detectedBarTransparent: {
        if (shell && shell.barConfig && typeof shell.barConfig.transparent === "boolean") {
            return shell.barConfig.transparent
        }
        return false
    }

    readonly property string systemBarPosition: (shell && shell.bar && shell.bar.position)
        ? shell.bar.position : detectedBarPosition
    readonly property string dockScreenPosition: root.taskbarActive ? "bottom" : DockSettings.resolveDockPosition(
        root.dockPosition, root.profile, root.systemBarPosition)
    readonly property bool isVertical: dockScreenPosition === "left" || dockScreenPosition === "right"
    // Existing surfaces, animations and menus use the opposite edge as their
    // layout origin. It is independent of the real system bar for manual placement.
    readonly property string barPosition: DockSettings.oppositeEdge(dockScreenPosition)

    // Live Bar & Tray Transparency Tracking (Auto-syncs dock with bar & tray glassmorphism)
    readonly property bool isBarTransparent: {
        if (shell && shell.bar && typeof shell.bar.transparent === "boolean") return shell.bar.transparent
        return detectedBarTransparent
    }

    readonly property color dockBackgroundColor: appearance.backgroundColor
    readonly property bool dockBackgroundTransparent: appearance.backgroundTransparent

    // Static Standard Dock Geometry (Strictly stable, no jumping/twitching on window state)
    readonly property real slotSize: DockSettings.dockGeometry(dockSize).slot
    readonly property real iconBaseSize: DockSettings.dockGeometry(dockSize).icon

    readonly property var drag: dragState
    DockDragState { id: dragState }
    readonly property int dockDragActiveIndex: drag.dockIndex
    readonly property int dockDragTargetIndex: drag.dockTarget
    readonly property int currentMergeTargetIndex: drag.mergeTarget
    readonly property int folderDragActiveIndex: drag.folderIndex
    readonly property int folderDragTargetIndex: drag.folderTarget

    // Direct IPC handler for io.github.tcballard.familiar-desktop target
    IpcHandler {
        target: "io.github.tcballard.familiar-desktop"
        function open(): string { root.open(""); return "ok" }
        function close(): string { root.close(); return "ok" }
        function toggle(): string { root.toggle(); return "ok" }
        function refresh(): string { return root.refresh() }
        function openWidgetPicker(): string {
            root.openWidgetPicker()
            return "ok"
        }
        function addWidget(widgetId: string): string { root.addDockWidget(widgetId); return "ok" }
        function removeWidget(widgetId: string): string { root.removeDockWidget(widgetId, ""); return "ok" }
        function setShowAppMenu(val: string): string { root.setShowAppMenu(val === "true" || val === "1"); return "ok" }
        function setAppMenuPosition(pos: string): string { root.setAppMenuPosition(pos); return "ok" }
        function setWidgetsEnabled(val: string): string { root.setWidgetsEnabled(val === "true" || val === "1"); return "ok" }
        function setWidgetPosition(pos: string): string { root.setWidgetPosition(pos); return "ok" }
        function setEditMode(val: string): string { root.interaction.setEditing((val === "true" || val === "1")); return "ok" }
        function setDockEnabled(val: string): string { root.dockEnabled = (val === "true" || val === "1"); root.saveSettings(); return "ok" }
        function setAutohide(val: string): string { root.setAutohide(val === "true" || val === "1"); return "ok" }
        function setVisibilityMode(mode: string): string { root.setVisibilityMode(mode); return "ok" }
        function setProfile(profile: string): string { root.setProfile(profile); return root.profile }
        function titlebarStatus(): string { return JSON.stringify({ state: titlebars.state, message: titlebars.message, busy: titlebars.busy }) }
        function refreshTitlebars(): string { titlebars.refresh(); return "ok" }
        function setVisibleWorkspace(workspace: string): string { root.setVisibleWorkspace(workspace); return "ok" }
        function toggleReveal(): string { return root.toggleReveal() }
        function setAutohideEdgeDepth(val: string): string { var n = parseInt(val, 10); if (!isNaN(n) && n >= 1 && n <= 64) { root.autohideEdgeDepth = n; root.saveSettings(); } return "ok" }
        function setShowFolderTitles(val: string): string { root.showFolderTitles = (val === "true" || val === "1"); root.saveSettings(); return "ok" }
        function setShowBadges(val: string): string { root.showBadges = (val === "true" || val === "1"); root.saveSettings(); return "ok" }
        function setOverlayMode(val: string): string { root.overlayMode = (val === "true" || val === "1"); root.saveSettings(); return "ok" }
        function showDesktop(): string { return desktopToolsAdapter.run(["show"]) ? "started" : "busy" }
        function restoreDesktop(): string { return desktopToolsAdapter.run(["restore"]) ? "started" : "busy" }
        function taskbarStatus(): string { return JSON.stringify({mode:taskbarController.mode, active:root.taskbarActive, busy:taskbarController.busy, profile:root.profile, message:taskbarController.message}) }
        function ping(): string { return "ok" }
        function panelStatus(): string {
            return JSON.stringify(root.dockItems.filter(function(item) { return !!item.pluginId }).map(function(item) {
                return {id: item.appId, pluginId: item.pluginId, icon: item.rawIcon, glyph: item.iconGlyph, windows: item.windowCount, active: item.isActive}
            }))
        }
    }

    function openWidgetPicker() {
        root.opened = true
        if (!visibility.prepareWidgetPicker()) return
        if (widgetPicker) {
            widgetPicker.opened = true
            visibility.cancelLeave()
        }
    }

    // Methods called by shell.summon / shell.hide / shell.toggle
    function open(payloadJson) {
        root.opened = true
        if (payloadJson) {
            try {
                var p = (typeof payloadJson === "string") ? JSON.parse(payloadJson) : payloadJson
                if (p && p.action === "openWidgetPicker") {
                    if (widgetPicker) widgetPicker.opened = true
                } else if (p && p.action === "closeWidgetPicker") {
                    if (widgetPicker) widgetPicker.opened = false
                }
            } catch(e) {}
        }
    }

    function close() {
        root.opened = false
        root.interaction.dismiss()
        root.drag.cancel()
    }

    function toggle() {
        root.opened = !root.opened
        root.interaction.dismiss()
        root.drag.cancel()
    }

    function toggleStack(item, index) { interaction.toggleFolder(item) }

    DockWindowTracker {
        id: windowTracker
        toplevelManager: ToplevelManager
        hyprland: Hyprland
        onRefreshRequested: root.updateDockItems()
        onIconRefreshRequested: iconScanDebounceTimer.restart()
        onFocusRequested: function(address) { DockCommands.run(Util, ["hyprctl", "dispatch", "focuswindow", "address:" + address]) }
    }
    readonly property var knownWindows: windowTracker.knownWindows
    readonly property var focusedWindowHistory: windowTracker.focusedWindowHistory
    function requestFocusOnLaunch(appId) { windowTracker.requestFocusOnLaunch(appId) }
    function windowLocation(top) { return windowTracker.windowLocation(top) }

    property string pendingTaskbarProfile: ""
    property var taskbarAnchorItem: null
    property real taskbarItemSize: 32
    readonly property bool taskbarSelected: taskbarController.mode === "enable" && root.systemBarPosition === "bottom"
        && (!root.shell || !root.shell.barConfig || !root.shell.barConfig.id || root.shell.barConfig.id === "omarchy.bar")
    property var taskbarHosts: []
    readonly property bool taskbarActive: root.taskbarSelected && root.taskbarHosts.length > 0
    function registerTaskbarHost(host) {
        if (taskbarHosts.indexOf(host) === -1) taskbarHosts = taskbarHosts.concat([host])
    }
    function unregisterTaskbarHost(host) {
        taskbarHosts = taskbarHosts.filter(function(item) { return item !== host })
    }
    function taskbarHostedOn(screen) {
        if (!taskbarSelected) return false
        for (var i = 0; i < taskbarHosts.length; i++) {
            var host = taskbarHosts[i]
            var window = host ? host.QsWindow.window : null
            if (window && window.screen === screen) return true
        }
        return false
    }
    readonly property var dockLayout: Geometry.panelLayout(root.dockScreenPosition, Style.gapsOut || 5, false)
    readonly property var edgeLayout: Geometry.panelLayout(root.dockScreenPosition, 0, false)
    function popupLayout(ignoreDockExclusion) {
        return Geometry.popupLayout({
            edge: root.dockScreenPosition, slotSize: root.slotSize, gap: Style.gapsOut || 5,
            taskbar: root.taskbarActive, taskbarSize: root.taskbarItemSize,
            overlay: root.overlayMode, ignoreDockExclusion: ignoreDockExclusion
        })
    }
    readonly property var appPopupLayout: popupLayout(true)
    readonly property var folderPopupLayout: popupLayout(false)
    readonly property real popupDockOffset: appPopupLayout.offset
    readonly property var popupAppearance: ({
        transparent: root.isBarTransparent, rounding: root.systemRounding,
        borderSpec: root.dockBorderSpec, borderAnimated: root.borderAngleAnimationEnabled,
        borderAnimationDuration: root.borderAngleAnimationDuration
    })
    readonly property real taskbarAnchorX: root.taskbarAnchorItem
        ? root.taskbarAnchorItem.mapToItem(null, root.taskbarAnchorItem.width / 2, 0).x : 0
    TaskbarController {
        id: taskbarController
        onCompleted: function(operation) {
            if (operation !== "status" && root.pendingTaskbarProfile !== "") {
                var selected = root.pendingTaskbarProfile
                root.pendingTaskbarProfile = ""
                root.applyProfile(selected)
            }
        }
    }
    onTaskbarActiveChanged: {
        root.interaction.dismissApp()
        root.interaction.dismiss()
        root.taskbarAnchorItem = null
    }

    readonly property var capsLock: capsLockController
    CapsLockController { id: capsLockController }
    readonly property var windowMode: windowModeController
    WindowModeController { id: windowModeController }
    readonly property var gestures: gesturesController
    GesturesController { id: gesturesController }
    readonly property var borderResize: borderResizeController
    InputPreferenceController { id: borderResizeController; kind: "resize" }
    readonly property var commandShortcuts: commandShortcutsController
    InputPreferenceController { id: commandShortcutsController; kind: "command" }

    readonly property var desktopTools: desktopToolsAdapter
    DesktopActions { id: desktopToolsAdapter; onCompleted: function(operation) { root.updateDockItems(); windowTracker.refreshSoon() } }

    property alias fileShortcutsEnabled: settings.fileShortcutsEnabled
    readonly property real fileShortcutsSize: fileShortcutsEnabled ? 3 * slotSize : 0
    property string desktopActionError: ""
    readonly property bool desktopActionBusy: desktopActionProcess.running
    function desktopAction(mode, target) {
        if (desktopActionBusy) return
        desktopActionError = ""
        desktopActionProcess.command = [Qt.resolvedUrl("bin/familiar-desktop").toString().replace(/^file:\/\//, ""), "dock", mode, target]
        desktopActionProcess.running = true
    }
    Process {
        id: desktopActionProcess
        stdout: StdioCollector { id: desktopActionOutput; waitForEnd: true }
        onExited: function(code, status) {
            var result = null
            try { result = JSON.parse(desktopActionOutput.text) } catch (e) {}
            if (code !== 0 || !result || result.state !== "ok") {
                root.desktopActionError = result && result.message ? String(result.message).slice(0, 300) : "Action failed. Check the installed Familiar backend."
            } else {
                root.interaction.dismissApp()
                root.updateDockItems()
                windowTracker.refreshSoon()
            }
        }
    }
    readonly property var interaction: dockInteraction
    DockInteraction { id: dockInteraction; items: root.dockItems }
    readonly property string contextAppId: interaction.app ? interaction.app.appId : ""
    readonly property int contextAppIndex: interaction.app ? interaction.selectedIndex : -1
    readonly property var contextApp: interaction.app
    readonly property bool hasActiveDockInteraction: interaction.popup !== "none" || isEditMode || !!(root.widgetPicker && root.widgetPicker.opened)
    Connections {
        target: dockInteraction
        function onPopupChanged() { root.evaluateHoverState() }
    }

    function toggleAppMenu(item, index) {
        root.desktopActionError = ""
        interaction.toggleApp(item)
    }
    function toggleMenu(item, index) { interaction.toggleFolderMenu(item) }

    // Standalone plugin lifecycle: enabled by default, disabled ONLY if in disabledPlugins
    function updatePluginEnabled() {
        var reg = root.pluginRegistry || (shell ? shell.pluginRegistry : null)
        if (reg && typeof reg.isEnabled === "function") {
            root.pluginEnabled = reg.isEnabled("io.github.tcballard.familiar-desktop")
            return
        }
        try {
            var raw = shellConfigFile.text()
            if (raw && raw.length > 0) {
                var cfg = JSON.parse(raw)
                if (cfg) {
                    if (Array.isArray(cfg.disabledPlugins) && cfg.disabledPlugins.indexOf("io.github.tcballard.familiar-desktop") !== -1) {
                        root.pluginEnabled = false
                        return
                    }
                    if (Array.isArray(cfg.plugins)) {
                        for (var p = 0; p < cfg.plugins.length; p++) {
                            if (cfg.plugins[p] && (cfg.plugins[p].id === "io.github.tcballard.familiar-desktop" || cfg.plugins[p] === "io.github.tcballard.familiar-desktop")) {
                                root.pluginEnabled = true
                                return
                            }
                        }
                    }
                    if (cfg.bar && cfg.bar.layout) {
                        for (var s in cfg.bar.layout) {
                            var arr = cfg.bar.layout[s] || []
                            for (var k = 0; k < arr.length; k++) {
                                var entry = arr[k]
                                if (entry && (entry.id === "io.github.tcballard.familiar-desktop" || entry === "io.github.tcballard.familiar-desktop")) {
                                    root.pluginEnabled = true
                                    return
                                }
                            }
                        }
                    }
                }
            }
        } catch(e) {}
        root.pluginEnabled = true
    }

    function parseShellConfigFile() {
        root.updatePluginEnabled()
        try {
            var raw = shellConfigFile.text()
            if (raw && raw.length > 0) {
                var cfg = JSON.parse(raw)
                if (cfg && cfg.bar) {
                    if (cfg.bar.position && root.detectedBarPosition !== cfg.bar.position) {
                        root.detectedBarPosition = cfg.bar.position
                    }
                    if (cfg.bar.transparent !== undefined && root.detectedBarTransparent !== (cfg.bar.transparent === true)) {
                        root.detectedBarTransparent = (cfg.bar.transparent === true)
                    }
                }
            }
        } catch(e) {}
    }

    FileView {
        id: shellConfigFile
        path: root.shellConfigPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.parseShellConfigFile()
        onFileChanged: reload()
    }

    // Dock visibility, placement, and folder settings
    property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy/familiar-desktop-settings.json"
    property alias dockBackgroundOpacity: settings.dockBackgroundOpacity
    property alias dockSize: settings.dockSize
    property alias dockPosition: settings.dockPosition
    property alias titlebarSize: settings.titlebarSize
    property alias titlebarsEnabled: settings.titlebarsEnabled
    property alias titlebarMode: settings.titlebarMode
    property alias titlebarStyle: settings.titlebarStyle
    property alias titlebarExclusions: settings.titlebarExclusions
    property alias skipBrowserTitlebars: settings.skipBrowserTitlebars
    readonly property string titlebarState: titlebars.state
    readonly property string titlebarMessage: titlebars.message
    readonly property bool titlebarBusy: titlebars.busy
    function refreshTitlebars() { titlebars.refresh() }
    TitlebarController {
        id: titlebars
        available: setupController.ready
        enabled: root.titlebarMode !== "off" && root.pluginEnabled && root.dockEnabled
        mode: root.titlebarMode
        style: root.titlebarStyle
        exclusions: root.titlebarExclusions
        skipBrowserTitlebars: root.skipBrowserTitlebars
        size: root.titlebarSize
        background: Commons.Color.popups.background
        foreground: Commons.Color.popups.text
        fontFamily: Style.font.family
        fontSize: Math.max(8, Math.min(32, Style.font.subtitle))
    }
    property alias profile: settings.profile
    property alias shortcutLabels: settings.shortcutLabels
    property alias dockEnabled: settings.dockEnabled
    property alias visibilityMode: settings.visibilityMode
    property alias preferredVisibilityMode: settings.preferredVisibilityMode
    readonly property bool autohide: root.visibilityMode !== "always"
    property alias overlayMode: settings.overlayMode
    readonly property int visibilityOverride: visibility.overrideMode
    property alias visibleWorkspace: settings.visibleWorkspace
    property alias autohideEdgeDepth: settings.autohideEdgeDepth
    readonly property int effectiveAutohideEdgeDepth: Math.max(4, Math.min(64, root.autohideEdgeDepth))
    property alias showFolderTitles: settings.showFolderTitles
    property alias showBadges: settings.showBadges
    property alias windowPreviews: settings.windowPreviews
    property alias glassmorphism: settings.glassmorphism
    property alias blurOpacity: settings.blurOpacity
    readonly property bool showAppMenu: root.widgetsEnabled && root.dockWidgets && (root.dockWidgets.indexOf("omarchy.apps") !== -1)
    property alias appMenuPosition: settings.appMenuPosition
    property alias widgetsEnabled: settings.widgetsEnabled
    property alias widgetPosition: settings.widgetPosition
    property alias dockWidgets: settings.dockWidgets
    property alias widgetSavedPositions: settings.widgetSavedPositions
    readonly property bool isDockHovered: visibility.hovered
    property bool isStackHovered: false
    property bool isMenuHovered: false
    property bool isWidgetPanelHovered: false

    DockVisibility {
        id: visibility
        hyprland: Hyprland
        toplevelManager: ToplevelManager
        screens: Quickshell.screens || []
        mode: root.visibilityMode
        workspaceSelector: root.visibleWorkspace
        available: setupController.ready && root.opened && root.pluginEnabled && root.dockEnabled && root.isPinnedLoaded
        remapping: remapTimer.running
        taskbarActive: root.taskbarActive
        dockSurfaces: dockVariants.instances || []
        popupHovered: root.isStackHovered || root.isMenuHovered || root.isWidgetPanelHovered || windowPreview.opened
        interactionActive: root.hasActiveDockInteraction
        dragActive: root.dockDragActiveIndex >= 0
        widgetPanelsOpen: function() { return root.checkWidgetPanelsOpen() }
        onClosePopupsRequested: root.closePopups()
    }
    readonly property var effectiveDockScreen: visibility.effectiveScreen
    readonly property bool workspaceAllowed: visibility.workspaceAllowed
    readonly property bool dockAvailable: visibility.dockAvailable
    readonly property bool dockMapped: visibility.mapped
    readonly property bool dockRevealed: visibility.revealed
    readonly property bool shouldSlideOut: visibility.shouldSlideOut
    readonly property string revealTargetMonitorName: visibility.revealTargetMonitorName
    function screenForMonitor(monitor) { return visibility.screenForMonitor(monitor) }
    function screenShowsDock(screen) { return visibility.screenShowsDock(screen) }
    function screenSlidesOut(screen) { return visibility.screenSlidesOut(screen) }

    property var loadedWidgetItems: []

    property string currentMinuteString: Qt.formatDateTime(new Date(), "dddd HH:mm")
    property string currentHourString: Qt.formatDateTime(new Date(), "HH")
    property string currentMinutePart: Qt.formatDateTime(new Date(), "mm")

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: root.hasClockWidget
        onTriggered: {
            var now = new Date()
            var minStr = Qt.formatDateTime(now, "dddd HH:mm")
            if (root.currentMinuteString !== minStr) {
                root.currentMinuteString = minStr
                root.currentHourString = Qt.formatDateTime(now, "HH")
                root.currentMinutePart = Qt.formatDateTime(now, "mm")
            }
        }
    }

    function checkWidgetPanelsOpen() {
        if (widgetPicker && widgetPicker.opened) return true
        if (root.loadedWidgetItems) {
            for (var i = 0; i < root.loadedWidgetItems.length; i++) {
                var w = root.loadedWidgetItems[i]
                if (w) {
                    if (w.opened === true) return true
                    if (w.panelLoader && w.panelLoader.item && w.panelLoader.item.opened === true) return true
                    if (w.panel && w.panel.open === true) return true
                }
            }
        }
        if (root.shell && root.shell.openPanelIds) {
            // openPanelIds is a set the shell adds to on summon and removes
            // from on hide, so a panel that closes itself can leave its id
            // behind. The shell's own isPluginOpen() knows this and prefers
            // the panel's live `opened` property, falling back to the set only
            // when there is nothing live to ask. Trusting the raw set instead
            // pins the dock open for the rest of the session.
            var askShell = typeof root.shell.isPluginOpen === "function"
            for (var k in root.shell.openPanelIds) {
                if (root.shell.openPanelIds[k] !== true) continue
                if (!askShell || root.shell.isPluginOpen(k)) return true
            }
        }
        return false
    }

    function closeAllWidgetPanels() {
        if (widgetPicker && widgetPicker.opened) widgetPicker.close()
        if (root.shell && typeof root.shell.closeAllPanels === "function") {
            root.shell.closeAllPanels()
        }
        if (root.loadedWidgetItems) {
            for (var i = 0; i < root.loadedWidgetItems.length; i++) {
                var w = root.loadedWidgetItems[i]
                if (w) {
                    if (typeof w.close === "function") {
                        w.close()
                    }
                    if (w.panelLoader && w.panelLoader.item && typeof w.panelLoader.item.close === "function") {
                        w.panelLoader.item.close()
                    }
                    if (w.panel && typeof w.panel.close === "function") {
                        w.panel.close()
                    }
                }
            }
        }
    }

    function evaluateHoverState() { visibility.evaluateHoverState() }
    function toggleReveal(source) { return visibility.toggleReveal(source) }
    function handleWidgetPickerOpenedChanged(opened) { visibility.widgetPickerOpenedChanged(opened) }

    property var lastRemapScreen: null
    onEffectiveDockScreenChanged: {
        if (root.lastRemapScreen !== root.effectiveDockScreen) {
            root.lastRemapScreen = root.effectiveDockScreen
            var target = DockSettings.dockScreenTarget(
                root.visibleWorkspace,
                root.visibilityMode,
                root.visibilityOverride
            )
            if (target !== "all") remapTimer.restart()
        }
    }

    readonly property var widgetLayout: DockModel.getDockWidgetLayout(root.showAppMenu, root.appMenuPosition, root.widgetsEnabled, root.dockWidgets, root.widgetPosition)
    readonly property var leftWidgetsList: widgetLayout.leftWidgets || []
    readonly property var rightWidgetsList: widgetLayout.rightWidgets || []
    readonly property bool hasLeftWidgets: leftWidgetsList.length > 0
    readonly property bool hasRightWidgets: rightWidgetsList.length > 0
    readonly property bool hasWidgets: hasLeftWidgets || hasRightWidgets

    readonly property bool hasClockOnLeft: hasLeftWidgets && leftWidgetsList.indexOf("omarchy.clock") !== -1
    readonly property bool hasClockOnRight: hasRightWidgets && rightWidgetsList.indexOf("omarchy.clock") !== -1
    readonly property bool hasClockWidget: hasClockOnLeft || hasClockOnRight

    property string clockDisplayText: ""

    TextMetrics {
        id: clockMetrics
        font.family: Style.font.family
        font.pixelSize: 12
        font.weight: Font.Medium
        text: root.clockDisplayText !== "" ? root.clockDisplayText : root.currentMinuteString
    }

    readonly property real clockSlotWidth: (hasClockWidget && !root.isVertical)
        ? Math.max(root.slotSize, clockMetrics.advanceWidth + 24)
        : root.slotSize

    function getLeftWidgetOffset(index) {
        var offset = 0
        for (var i = 0; i < index; i++) {
            var id = root.leftWidgetsList[i]
            var dim = (id === "omarchy.clock" && !root.isVertical) ? root.clockSlotWidth : root.slotSize
            offset += dim
        }
        return offset
    }

    function getRightWidgetOffset(index) {
        var offset = 0
        for (var i = 0; i < index; i++) {
            var id = root.rightWidgetsList[i]
            var dim = (id === "omarchy.clock" && !root.isVertical) ? root.clockSlotWidth : root.slotSize
            offset += dim
        }
        return offset
    }

    readonly property real leftWidgetsWidth: {
        if (!hasLeftWidgets) return 0
        var total = 0
        for (var i = 0; i < leftWidgetsList.length; i++) {
            var id = leftWidgetsList[i]
            total += (id === "omarchy.clock" && !root.isVertical) ? root.clockSlotWidth : root.slotSize
        }
        return total
    }

    readonly property real rightWidgetsWidth: {
        if (!hasRightWidgets) return 0
        var total = 0
        for (var i = 0; i < rightWidgetsList.length; i++) {
            var id = rightWidgetsList[i]
            total += (id === "omarchy.clock" && !root.isVertical) ? root.clockSlotWidth : root.slotSize
        }
        return total
    }

    readonly property real leftSeparatorSize: hasLeftWidgets ? 8 : 0
    readonly property real rightSeparatorSize: hasRightWidgets ? 8 : 0
    readonly property real appRailOffset: root.hasLeftWidgets ? root.leftWidgetsWidth + root.leftSeparatorSize : 0
    readonly property var dockSurfaceSize: Geometry.surfaceSize(root.isVertical, root.slotSize, root.totalDockDimension)
    readonly property real itemsWidth: (root.dockItems.length * root.slotSize)

    // Dynamic max items limit for dock bar based on logical screen dimensions & scale (15 items on 1080p @ 1.6x, scales dynamically for Ultrawide 21:9 / 32:9)
    readonly property var activeScreen: {
        var focused = root.screenForMonitor(Hyprland.focusedMonitor)
        if (focused) return focused
        return (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
    }
    readonly property real logicalScreenWidth: (activeScreen && activeScreen.width > 0) ? activeScreen.width : 1200
    readonly property real logicalScreenHeight: (activeScreen && activeScreen.height > 0) ? activeScreen.height : 675
    readonly property int maxDockItems: {
        if (root.isVertical) {
            // Vertical: limit by screen height minus widget slots
            var usedV = root.fileShortcutsSize + (hasLeftWidgets ? (leftWidgetsWidth + leftSeparatorSize) : 0)
                      + (hasRightWidgets ? (rightSeparatorSize + rightWidgetsWidth) : 0)
            var availableH = Math.max(0, logicalScreenHeight - usedV)
            return Math.max(3, Math.floor(availableH / root.slotSize))
        } else {
            // Horizontal: limit by screen width minus widget slots
            var usedH = root.fileShortcutsSize + (hasLeftWidgets ? (leftWidgetsWidth + leftSeparatorSize) : 0)
                      + (hasRightWidgets ? (rightSeparatorSize + rightWidgetsWidth) : 0)
            var availableW = Math.max(0, logicalScreenWidth - usedH)
            return Math.max(3, Math.floor(availableW / root.slotSize))
        }
    }

    readonly property real totalDockDimension: Math.max(root.slotSize, root.fileShortcutsSize +
        (hasLeftWidgets ? (leftWidgetsWidth + leftSeparatorSize) : 0) +
        itemsWidth +
        (hasRightWidgets ? (rightSeparatorSize + rightWidgetsWidth) : 0))

    onDockEnabledChanged: {
        if (!dockEnabled) {
            root.interaction.dismiss()
        }
    }

    SettingsStore { id: settings; path: root.settingsPath }

    function saveSettings() { return settings.save() }
    readonly property string settingsError: settings.error

    function setPreference(key, value) {
        var changes = {}; changes[key] = value
        return settings.patch(changes)
    }
    function setTitlebarMode(mode) {
        if (["off", "theme", "mac", "windows"].indexOf(mode) < 0) return false
        var changes = {titlebarMode: mode, titlebarsEnabled: mode !== "off"}
        if (mode !== "off") changes.dockEnabled = true
        if (mode === "mac" || mode === "windows") changes.titlebarStyle = mode
        return settings.patch(changes)
    }

    function setDockEnabled(val) {
        root.dockEnabled = (val === true || val === "true" || val === 1 || val === "1")
        saveSettings()
    }

    function setProfile(value) {
        var selected = DockSettings.normalizeProfile(value)
        if (taskbarController.run(selected === "windows" ? "enable" : "reset"))
            root.pendingTaskbarProfile = selected
    }

    function applyProfile(value) {
        var selected = DockSettings.normalizeProfile(value)
        var defaults = DockSettings.profileDefaults(selected)
        root.profile = selected
        root.dockEnabled = true
        root.visibilityMode = defaults.visibilityMode
        root.overlayMode = defaults.overlayMode
        root.titlebarStyle = defaults.titlebarStyle
        if (root.titlebarMode !== "theme" && root.titlebarMode !== "off") root.titlebarMode = defaults.titlebarStyle
        root.interaction.dismissApp()
        root.interaction.dismiss()
        root.saveSettings()
    }

    function setAutohide(val) {
        var keybind = root.visibilityMode === "keybind" || root.visibilityMode === "hybrid"
        settings.patch({dockEnabled: true, visibilityMode: val ? (keybind ? "hybrid" : "hover") : (keybind ? "keybind" : "always")})
    }
    function setKeybindMode(val) {
        var hover = root.visibilityMode === "hover" || root.visibilityMode === "hybrid"
        settings.patch({dockEnabled: true, visibilityMode: val ? (hover ? "hybrid" : "keybind") : (hover ? "hover" : "always")})
    }

    function setVisibilityMode(mode) {
        var norm = DockSettings.normalizeVisibilityMode(mode, false)
        if (norm === "hover" || norm === "keybind") {
            root.preferredVisibilityMode = norm
        }
        root.visibilityMode = norm
        saveSettings()
    }

    function setVisibleWorkspace(workspace) {
        root.visibleWorkspace = DockSettings.normalizeVisibleWorkspace(workspace)
        saveSettings()
    }

    function setOverlayMode(val) {
        root.overlayMode = (val === true || val === "true")
        root.saveSettings()
    }

    function setShowAppMenu(val) {
        if (val) {
            root.addDockWidget("omarchy.apps")
        } else {
            root.removeDockWidget("omarchy.apps", "")
        }
    }

    function setWidgetsEnabled(val) {
        root.widgetsEnabled = val
        saveSettings()
    }

    function setAppMenuPosition(pos) {
        root.appMenuPosition = (pos === "right") ? "right" : "left"
        saveSettings()
    }

    function setWidgetPosition(pos) {
        root.widgetPosition = (pos === "left") ? "left" : "right"
        saveSettings()
    }

    function addDockWidget(widgetId) {
        if (!DockModel.validWidgetId(widgetId)) return
        if (widgetId !== "omarchy.apps" && !root.getWidgetComponent(widgetId) && !root.getWidgetSource(widgetId)) return
        root.widgetsEnabled = true
        root.dockWidgets = DockModel.addWidgetToDockList(root.dockWidgets, widgetId)
        saveSettings()
    }

    function removeDockWidget(widgetId, targetRegion) {
        root.dockWidgets = DockModel.removeWidgetFromDockList(root.dockWidgets, widgetId)
        saveSettings()
    }

    // Preferred route since Omarchy 4.0.3: the widget-catalogue facade hands out
    // the live Component for anything the host has registered, which is every
    // enabled bar-widget plugin. Returns null when the widget is not registered,
    // leaving getWidgetSource() to cover the hardcoded first-party panels.
    function getWidgetComponent(widgetId) {
        if (!DockModel.validWidgetId(widgetId) || widgetId === "omarchy.apps") return null
        if (!root.barWidgetRegistry) return null
        var widgets = root.barWidgetRegistry.widgets || {}
        var entry = widgets[widgetId]
        return entry && entry.component ? entry.component : null
    }

    function getWidgetSource(widgetId) {
        if (!DockModel.validWidgetId(widgetId) || widgetId === "omarchy.apps") return ""
        var manifest = (root.shell && root.shell.pluginRegistry && root.shell.pluginRegistry.installedPlugins) ? root.shell.pluginRegistry.installedPlugins[widgetId] : null
        if (manifest && root.shell && root.shell.pluginRegistry) {
            var ep = root.shell.pluginRegistry.entryPointUrl(manifest, "barWidget")
            if (ep && ep.length > 0) return ep
        }
        if (!/^omarchy\.[a-z0-9-]+$/.test(widgetId)) return ""
        var name = widgetId.slice(8)

        // 1. Built-in bar widgets in plugins/bar/widgets/
        if (name === "indicators") return "file:///usr/share/omarchy/shell/plugins/bar/widgets/Indicators.qml"
        if (name === "keyboard-layout") return "file:///usr/share/omarchy/shell/plugins/bar/widgets/KeyboardLayout.qml"
        if (name === "microphone") return "file:///usr/share/omarchy/shell/plugins/bar/widgets/Microphone.qml"

        // 2. Services bar widgets
        if (name === "media") return "file:///usr/share/omarchy/shell/plugins/services/media/BarWidget.qml"

        // 3. Root plugin bar widgets / panels
        if (name === "agents") return "file:///usr/share/omarchy/shell/plugins/agents/Panel.qml"
        if (name === "menu") return "file:///usr/share/omarchy/shell/plugins/menu/BarWidget.qml"

        // 4. Panel widgets using Panel.qml
        if (name === "audio" || name === "bluetooth" || name === "network" ||
            name === "power" || name === "monitor" || name === "tailscale" ||
            name === "dropbox" || name === "speedtest" || name === "disk-speedtest" ||
            name === "wifiqr") {
            return "file:///usr/share/omarchy/shell/plugins/panels/" + name + "/Panel.qml"
        }

        // 5. Panel widgets using BarWidget.qml
        if (name === "clock" || name === "weather") {
            return "file:///usr/share/omarchy/shell/plugins/panels/" + name + "/BarWidget.qml"
        }

        if (manifest && (!manifest.entryPoints || !manifest.entryPoints.barWidget)) {
            return ""
        }
        return ""
    }

    function configureHostedWidget(item, widgetId, anchorItem) {
        HostedWidgets.attach(widgetHost, item, widgetId, anchorItem)
        root.widgetIconRevision++
    }
    QtObject {
        id: widgetHost
        readonly property var loadedWidgetItems: root.loadedWidgetItems
        readonly property var shell: root.shell
        readonly property var barContext: dockBarContext
        readonly property var dockWindow: root.dockWindow
        function evaluateHoverState() { root.evaluateHoverState() }
        property alias widgetIconRevision: root.widgetIconRevision
    }

    // The visual delegate receives only the widget-host operations it needs.
    QtObject {
        id: widgetActions
        function componentFor(id) { return root.getWidgetComponent(id) }
        function sourceFor(id) { return root.getWidgetSource(id) }
        function attach(item, id, anchor) { root.configureHostedWidget(item, id, anchor) }
        function iconFor(id, item) { return root.getWidgetIcon(id, item) }
        function activate(id, item, anchor, mouse) { root.activateWidget(id, item, anchor, mouse) }
    }

    // Proxy Bar context for hosted widgets
    QtObject {
        id: dockBarContext
        property bool vertical: root.isVertical
        property int barSize: root.slotSize + 8
        property int barH: root.slotSize + 8
        property int barW: root.slotSize + 8
        property string position: root.dockScreenPosition
        property var screen: (root.dockWindow && root.dockWindow.screen) ? root.dockWindow.screen : null
        property var shell: root.shell
        property color foreground: Commons.Color.composed("bar.text", "bar.text-alpha", Commons.Color.text, 0.9)
        property color barForeground: Commons.Color.composed("bar.text", "bar.text-alpha", Commons.Color.text, 0.9)
        property color urgent: Commons.Color.urgent
        property color muted: Commons.Color.muted
        property color accent: Commons.Color.accent
        property bool foregroundAnimationEnabled: true
        property string fontFamily: Style.font.family
        property var activePopout: null
        function showTooltip(item, text) {}
        function hideTooltip(item) {}
        function requestPopout(key) { activePopout = key }
        function releasePopout(key) { if (activePopout === key) activePopout = null }
        function isBarWidgetOpen(id) { return false }
        function switchPanelFrom(panel, dir) { return false }
        function run(cmd) { Util.execDetached(cmd) }
    }

    // Reactive tracking for hardware and system states
    property int widgetIconRevision: 0
    onWidgetIconRevisionChanged: updateDockItems()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var pipewireDefaultSinkAudio: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio : null
    readonly property real pipewireSinkVolume: pipewireDefaultSinkAudio ? pipewireDefaultSinkAudio.volume : 1.0
    readonly property bool pipewireSinkMuted: pipewireDefaultSinkAudio ? pipewireDefaultSinkAudio.muted : false

    readonly property var pipewireDefaultSourceAudio: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio : null
    readonly property bool pipewireSourceMuted: pipewireDefaultSourceAudio ? pipewireDefaultSourceAudio.muted : true

    readonly property var upowerDisplayDev: UPower.displayDevice
    readonly property real upowerBatteryPercentage: (upowerDisplayDev && upowerDisplayDev.isPresent) ? upowerDisplayDev.percentage : 100.0
    readonly property int upowerBatteryState: (upowerDisplayDev && upowerDisplayDev.isPresent) ? upowerDisplayDev.state : 0
    readonly property bool upowerBatteryPresent: (upowerDisplayDev && upowerDisplayDev.isPresent) ? true : false

    readonly property int screenCount: Quickshell.screens ? Quickshell.screens.length : 1

    function getWidgetIcon(widgetId, item) {
        var _rev = root.widgetIconRevision
        if (!widgetId) return "󰒓"
        if (widgetId === "omarchy.apps") return "󰀻"
        if (widgetId === "omarchy.monitor") {
            return (root.screenCount > 1) ? "󰍺" : "󰍹"
        }
        if (widgetId === "omarchy.clock") return "󰥔"
        if (widgetId === "omarchy.tailscale") {
            if (item && item.icon) return item.icon
            return "󰖂"
        }
        if (widgetId === "omarchy.network") {
            if (item && item.icon) return item.icon
            return "󰖩"
        }
        if (widgetId === "omarchy.bluetooth") {
            if (item && item.icon) return item.icon
            return "󰂯"
        }
        if (widgetId === "omarchy.weather") {
            if (item && item.icon) return item.icon
            return "󰖐"
        }
        if (widgetId === "omarchy.system-update") return "󰚰"
        if (widgetId === "omarchy.microphone") {
            if (item && item.muted !== undefined) return item.muted ? "󰍭" : "󰍬"
            return root.pipewireSourceMuted ? "󰍭" : "󰍬"
        }
        if (widgetId === "omarchy.media") {
            if (item && item.playIcon) return item.playIcon
            return "󰐊"
        }
        if (widgetId === "omarchy.keyboard-layout" || widgetId === "nomarkoo.keyboard-layout" || widgetId === "glafeara.languages") {
            if (item && item.icon) return item.icon
            if (item && item.displayText) return item.displayText
            return "󰌌"
        }
        if (widgetId === "omarchy.tray") return "󰇙"
        if (widgetId === "omarchy.agents") return "󰚩"
        if (widgetId === "io.github.tcballard.rss-feed") return ""
        if (widgetId === "omarchy.indicators") return "󰂚"
        if (widgetId === "silvaio.gamemode") return "󰊴"
        if (widgetId === "lgse.sandman") return "󰒲"
        if (widgetId === "omarchy.clipboard") return "󰅌"
        if (widgetId === "omarchy.emojis") return "󰞅"
        if (widgetId === "omarchy.reminders") return "󰔢"
        if (widgetId === "omarchy.speedtest") return "󰓅"
        if (widgetId === "omarchy.disk-speedtest") return "󰋊"
        if (widgetId === "omarchy.dropbox") return "󰇣"
        if (widgetId === "omarchy.wifiqr") return "󰒍"
        if (widgetId === "icons") return "󰀻"
        if (widgetId === "omaplug") return "󰏖"
        if (widgetId === "omarchy.audio") {
            if (item && typeof item.outputIcon === "function") {
                try {
                    var out = item.outputIcon()
                    if (out) return out
                } catch(e) {}
            }
            if (root.pipewireSinkMuted || root.pipewireSinkVolume <= 0.01) return "󰝟"
            if (root.pipewireSinkVolume < 0.33) return "󰕿"
            if (root.pipewireSinkVolume < 0.66) return "󰖀"
            return "󰕾"
        }
        if (widgetId === "omarchy.power") {
            if (item && typeof item.batteryIcon === "function") {
                try {
                    var bIcon = item.batteryIcon()
                    if (bIcon) return bIcon
                } catch(e) {}
            }
            if (!root.upowerBatteryPresent) return "󰚥"
            if (root.upowerBatteryState === UPowerDeviceState.Charging) return "󰂄"
            var frac = root.upowerBatteryPercentage / 100.0
            if (frac < 0.15) return "󰁺"
            if (frac < 0.30) return "󰁻"
            if (frac < 0.50) return "󰁽"
            if (frac < 0.70) return "󰁾"
            if (frac < 0.90) return "󰁿"
            return "󰁹"
        }
        if (item) {
            if (item.icon) return item.icon
            if (item.text) return item.text
            if (item.glyph) return item.glyph
            if (item.displayText) return item.displayText
        }
        var manifest = (root.shell && root.shell.pluginRegistry && root.shell.pluginRegistry.installedPlugins) ? root.shell.pluginRegistry.installedPlugins[widgetId] : null
        if (manifest) {
            if (manifest.icon) return manifest.icon
            if (manifest.barWidget && manifest.barWidget.icon) return manifest.barWidget.icon
        }
        return "󰒓"
    }

    function handleWidgetSlotClick(widgetId, mouse) {
        if (root.isEditMode) {
            if (mouse && mouse.button === Qt.RightButton) {
                root.interaction.setEditing(false)
            }
            return
        }
        if (widgetId === "omarchy.apps") {
            if (mouse && mouse.button === Qt.RightButton) {
                Util.execDetached("omarchy-menu toggle root")
            } else {
                Util.execDetached("omarchy-menu toggle apps")
            }
            return
        }
        if (widgetId === "omarchy.clock") {
            if (mouse && mouse.button === Qt.MiddleButton) {
                Util.execDetached("omarchy-menu-timezone")
                return
            }
        }
        if (widgetId === "omarchy.microphone") {
            if (mouse && mouse.button === Qt.MiddleButton) {
                Util.execDetached("omarchy-shell shell toggle omarchy.audio")
                return
            }
            if (mouse && mouse.button === Qt.LeftButton) {
                if (root.pipewireDefaultSourceAudio) {
                    root.pipewireDefaultSourceAudio.muted = !root.pipewireDefaultSourceAudio.muted
                } else {
                    Util.execDetached("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
                }
                return
            }
        }
        if (widgetId === "omarchy.keyboard-layout") {
            Util.execDetached("hyprctl switchxkblayout all next")
            return
        }
        if (widgetId === "omarchy.system-update") {
            Util.execDetached("omarchy-launch-floating-terminal-with-presentation omarchy-update")
            return
        }

        // Reliable toggle for all other plugins and overlays:
        if (DockModel.validWidgetId(widgetId))
            DockCommands.run(Util, ["omarchy-shell", "shell", "toggle", widgetId])
    }

    function activateWidget(widgetId, target, slotRoot, mouse) {
        windowPreview.close()
        if (root.isEditMode) {
            if (mouse && mouse.button === Qt.RightButton) {
                root.interaction.setEditing(false)
            }
            return
        }
        if (widgetId === "omarchy.apps") {
            if (mouse && mouse.button === Qt.RightButton) {
                Util.execDetached("omarchy-menu toggle root")
            } else {
                Util.execDetached("omarchy-menu toggle apps")
            }
            return
        }
        if (widgetId === "omarchy.system-update") {
            Util.execDetached("omarchy-launch-floating-terminal-with-presentation omarchy-update")
            return
        }

        if (target) {
            root.configureHostedWidget(target, widgetId, slotRoot)
            if (mouse && mouse.button === Qt.RightButton) {
                if (typeof target.cycleFormat === "function") {
                    target.cycleFormat()
                    return
                } else if (typeof target.toggleAllMuted === "function") {
                    target.toggleAllMuted()
                    return
                } else if (typeof target.toggleBluetooth === "function") {
                    target.toggleBluetooth()
                    return
                }
            } else if (mouse && mouse.button === Qt.MiddleButton) {
                if (widgetId === "omarchy.microphone") {
                    Util.execDetached("omarchy-shell shell toggle omarchy.audio")
                    return
                } else if (target.bar && typeof target.bar.run === "function") {
                    target.bar.run("omarchy-menu-timezone")
                    return
                } else {
                    Util.execDetached("omarchy-menu-timezone")
                    return
                }
            } else {
                // Left click handling
                if (typeof target.cycleLayout === "function") {
                    target.cycleLayout()
                    return
                } else if (typeof target.runUpdate === "function") {
                    target.runUpdate()
                    return
                } else if (typeof target.toggleMute === "function") {
                    target.toggleMute()
                    return
                } else if (typeof target.togglePanel === "function") {
                    target.togglePanel()
                    return
                } else if (typeof target.toggle === "function") {
                    target.toggle()
                    return
                } else if (target.panel && typeof target.panel.toggle === "function") {
                    target.panel.toggle()
                    return
                } else if (typeof target.open === "function") {
                    if (target.opened) target.close()
                    else target.open()
                    return
                } else if (target.panel && typeof target.panel.open === "function") {
                    if (target.panel.opened) target.panel.close()
                    else target.panel.open()
                    return
                } else if ("opened" in target) {
                    target.opened = !target.opened
                    return
                }
            }
        }

        root.handleWidgetSlotClick(widgetId, mouse)
    }

    Connections {
        target: root.pluginRegistry || (shell && shell.pluginRegistry) || null
        ignoreUnknownSignals: true
        function onPluginsChanged() { root.updatePluginEnabled() }
    }

    // Safe compositor unmap-remap sequence on orientation shift
    Timer {
        id: remapTimer
        interval: 100
        repeat: false
        // The remap builds fresh surfaces whose HoverHandlers start out
        // unhovered and therefore emit no onHoveredChanged. Re-derive the
        // hover state by hand, or a dock that was hovered before the remap
        // would stay revealed with nothing left to ever clear the flag.
        onTriggered: root.evaluateHoverState()
    }

    property string lastRemapBarPosition: ""
    onBarPositionChanged: {
        if (root.lastRemapBarPosition !== root.barPosition) {
            if (root.lastRemapBarPosition !== "") {
                root.closePopups()
                root.interaction.dismissApp()
                root.drag.cancelDock()
            }
            root.lastRemapBarPosition = root.barPosition
            // Drop the sticky hover flag before the surfaces are rebuilt: the
            // pointer cannot be over a dock that does not exist yet, and the
            // edge trigger re-reveals the dock the moment it really is.
            visibility.clearHover()
            remapTimer.restart()
        }
    }

    // Periodic sync timer for guaranteed real-time layer alignment
    Timer {
        id: syncPollTimer
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            root.refreshLayers()
            root.refreshHyprlandOptions()
        }
    }

    // Real-time Bar Position detection via Hyprland layer shell
    Process {
        id: layersProc
        running: true
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    for (var mon in data) {
                        var levels = data[mon].levels || {}
                        for (var lvl in levels) {
                            var layers = levels[lvl] || []
                            for (var i = 0; i < layers.length; i++) {
                                var l = layers[i]
                                if (l.namespace === "omarchy-bar") {
                                    var newPos = (l.w < l.h) ? (l.x === 0 ? "left" : "right") : (l.y === 0 ? "top" : "bottom")
                                    if (root.detectedBarPosition !== newPos) {
                                        root.detectedBarPosition = newPos
                                    }
                                    return
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function refreshLayers() {
        if (!layersProc.running) layersProc.running = true
    }

    DockAppearance {
        id: appearance
        hyprland: Hyprland
        backgroundOpacity: root.dockBackgroundOpacity
        barTransparent: root.isBarTransparent
    }
    readonly property int systemBorderSize: appearance.systemBorderSize
    readonly property int systemRounding: appearance.systemRounding
    readonly property var dockBorderSpec: appearance.dockBorderSpec
    readonly property bool borderAngleAnimationEnabled: appearance.borderAngleAnimationEnabled
    readonly property real borderAngleAnimationDuration: appearance.borderAngleAnimationDuration
    function refreshHyprlandOptions() { appearance.refresh() }

    readonly property bool isEditMode: interaction.editingItems

    function closeAppWindows(appIdOrItem) {
        if (!appIdOrItem) return
        var toplevels = []
        if (typeof appIdOrItem === "string") {
            for (var i = 0; i < root.dockItems.length; i++) {
                if (root.dockItems[i].appId === appIdOrItem && root.dockItems[i].toplevels) {
                    toplevels = root.dockItems[i].toplevels
                    break
                }
            }
        } else if (appIdOrItem.toplevels) {
            toplevels = appIdOrItem.toplevels
        }
        for (var t = 0; t < toplevels.length; t++) {
            if (toplevels[t].close) toplevels[t].close()
        }
    }

    // Which window the helper script should act on, as a Hyprland address.
    // The script resolves a bare --index against Hyprland's client list, which
    // is ordered independently of the dock's own window order, so the two agree
    // only until Hyprland reshuffles. Name the window instead, and fall back to
    // the position only when the address cannot be resolved.
    function targetWindowArg(itemData, targetIndex) {
        if (!itemData || typeof targetIndex !== "number" || targetIndex < 0) return ""
        var tops = itemData.toplevels || []
        if (targetIndex >= tops.length) return ""
        var hyprTops = (typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values)
            ? Hyprland.toplevels.values
            : []
        return DockModel.hyprAddressFor(tops[targetIndex], hyprTops)
    }

    function minimizeItem(itemData, targetIndex) {
        if (!itemData) return
        var args = ["minimize-instance"]
        if (itemData.appId) args.push(itemData.appId)
        if (itemData.desktopId && itemData.desktopId !== itemData.appId) args.push(itemData.desktopId)
        if (itemData.exec) args.push(itemData.exec)
        if (itemData.appClass && itemData.appClass !== itemData.appId && itemData.appClass !== itemData.desktopId) args.push(itemData.appClass)
        if (itemData.toplevels && typeof targetIndex === "number" && targetIndex >= 0 && targetIndex < itemData.toplevels.length) {
            var topAppMin = itemData.toplevels[targetIndex].appId || ""
            if (topAppMin && topAppMin !== itemData.appId && topAppMin !== itemData.desktopId && topAppMin !== itemData.appClass) {
                args.push(topAppMin)
            }
        }
        var targetArg = root.targetWindowArg(itemData, targetIndex)
        if (targetArg) {
            args.push(targetArg)
        } else if (typeof targetIndex === "number" && targetIndex >= 0) {
            args.push("--index=" + targetIndex)
        }
        var scriptPath = Qt.resolvedUrl("bin/familiar-desktop").toString().replace(/^file:\/\//, "")
        DockCommands.run(Util, [scriptPath, "dock"].concat(args))
        root.updateDockItems()
        windowTracker.refreshSoon()
    }

    function restoreOrLaunchItem(itemData, targetIndex) {
        if (!itemData) return
        var args = ["activate-instance"]
        if (itemData.appId) args.push(itemData.appId)
        if (itemData.desktopId && itemData.desktopId !== itemData.appId) args.push(itemData.desktopId)
        if (itemData.exec) args.push(itemData.exec)
        if (itemData.appClass && itemData.appClass !== itemData.appId && itemData.appClass !== itemData.desktopId) args.push(itemData.appClass)
        if (itemData.toplevels && typeof targetIndex === "number" && targetIndex >= 0 && targetIndex < itemData.toplevels.length) {
            var topAppAct = itemData.toplevels[targetIndex].appId || ""
            if (topAppAct && topAppAct !== itemData.appId && topAppAct !== itemData.desktopId && topAppAct !== itemData.appClass) {
                args.push(topAppAct)
            }
        }
        var targetArg = root.targetWindowArg(itemData, targetIndex)
        if (targetArg) {
            args.push(targetArg)
        } else if (typeof targetIndex === "number" && targetIndex >= 0) {
            args.push("--index=" + targetIndex)
        }
        var scriptPath = Qt.resolvedUrl("bin/familiar-desktop").toString().replace(/^file:\/\//, "")
        var launchId = itemData.desktopId || itemData.appId || ""
        root.requestFocusOnLaunch(launchId)
        DockModel.setPendingCliHint(itemData.appId || itemData.desktopId || "", root.knownWindows)
        DockCommands.run(Util, [scriptPath, "dock"].concat(args))
        root.updateDockItems()
        windowTracker.refreshSoon()
    }

    // Right-Click Menu State
    readonly property var activeMenuItem: interaction.folderMenu
    readonly property bool isMenuOpen: activeMenuItem !== null
    readonly property var activeStackItem: interaction.folder
    readonly property int activeStackItemIndex: interaction.folder ? interaction.selectedIndex : -1
    readonly property bool isEditingFolderTitle: interaction.renamingFolder
    readonly property bool isStackOpen: activeStackItem !== null

    // Pinned apps persistence
    property string userPinnedPath: Quickshell.env("HOME") + "/.config/omarchy/familiar-desktop-pinned.json"
    property int iconRevision: 0
    property var pinnedIds: []
    property var dockItems: []
    property var appRows: (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []

    // Curated available symbols for folder icon personalization (Clean monochrome vector glyphs)
    readonly property var availableFolderIcons: ["󰉋", "󰒓", "󰞷", "󰝚", "󰊴", "󰏘", "󰭹", "󰖟", "󰕧", "󰈔", "󰍹", "󰖩", "󰌾", "♥"]

    function resolveIcon(itemObj) {
        return Icons.resolve(itemObj, {
            candidates: DockModel.getCandidates,
            diskIcon: DockModel.getDiskIcon,
            library: shell ? shell.appLibrary : null,
            iconPath: function(name) { return Quickshell.iconPath(name, true) },
            friendlyFallback: false
        })
    }

    function closePopups() {
        windowPreview.close()
        root.interaction.dismiss()
        root.drag.cancelFolder()
        root.drag.clearMerge()
        if (widgetPicker) widgetPicker.opened = false
        root.closeAllWidgetPanels()
        root.evaluateHoverState()
    }

    // Auto-dismiss open folders, folder icon editor, widget panels and edit mode when system notifications / OSD appear
    readonly property var notifService: (root.shell && typeof root.shell.serviceFor === "function") ? root.shell.serviceFor("omarchy.notifications") : null
    readonly property var notifPopupModel: (root.notifService && root.notifService.popupModel) ? root.notifService.popupModel : null
    readonly property int notifPopupCount: notifPopupModel ? notifPopupModel.count : 0

    onNotifPopupCountChanged: {
        if (notifPopupCount > 0) {
            root.closePopups()
        }
    }

    Connections {
        target: root.notifPopupModel ? root.notifPopupModel : null
        ignoreUnknownSignals: true
        function onRowsInserted() {
            root.closePopups()
        }
        function onCountChanged() {
            if (root.notifPopupCount > 0) {
                root.closePopups()
            }
        }
    }

    readonly property bool isOsdOpen: {
        if (!root.shell) return false
        if (root.shell.openPanelIds && root.shell.openPanelIds["omarchy.osd"]) return true
        if (root.shell.appLibrary && root.shell.appLibrary.launchOsdOpen) return true
        if (typeof root.shell.isPluginOpen === "function" && root.shell.isPluginOpen("omarchy.osd")) return true
        return false
    }

    onIsOsdOpenChanged: {
        if (isOsdOpen) {
            root.closePopups()
        }
    }

    readonly property var osdLoader: (root.shell && root.shell.panelLoaders) ? root.shell.panelLoaders["omarchy.osd"] : null
    readonly property var osdItem: (osdLoader && osdLoader.item) ? osdLoader.item : null
    readonly property bool osdItemOpened: (osdItem && osdItem.opened !== undefined) ? osdItem.opened : false

    onOsdItemOpenedChanged: {
        if (osdItemOpened) {
            root.closePopups()
        }
    }

    Connections {
        target: root.shell ? root.shell : null
        // Omarchy's scoped plugin shell (third-party installs) has no openPanelIds
        ignoreUnknownSignals: true
        function onOpenPanelIdsChanged() {
            if (root.shell && root.shell.openPanelIds) {
                if (root.shell.openPanelIds["omarchy.osd"] || root.shell.openPanelIds["omarchy.notifications"]) {
                    root.closePopups()
                }
            }
        }
    }

    Connections {
        target: (root.shell && root.shell.appLibrary) ? root.shell.appLibrary : null
        function onLaunchOsdOpenChanged() {
            if (root.shell && root.shell.appLibrary && root.shell.appLibrary.launchOsdOpen) {
                root.closePopups()
            }
        }
    }

    function refresh() {
        root.pinnedIds = DockModel.parsePinned(userPinnedFile.text() || "")
        root.refreshLayers()
        root.updatePluginEnabled()
        iconScanDebounceTimer.restart()
        root.updateDockItems()
        return "ok"
    }

    // Coalescing debounce timer to prevent signal storm while keeping UI instantaneous
    Timer {
        id: batchUpdateTimer
        interval: 16
        repeat: false
        onTriggered: root.doUpdateDockItems()
    }

    function updateDockItems() {
        batchUpdateTimer.restart()
    }

    NotificationTracker {
        id: notifTracker
        shell: root.shell
        knownWindows: root.knownWindows
        onBadgeChanged: root.doUpdateDockItems()
    }

    // Clearing a badge rebuilds dockItems, and the Repeater below then destroys
    // the very delegate whose click is still running. Every statement after the
    // call — the rest of onItemLeftClicked, and DockItem's own handler, which
    // has not yet asked for the window — would execute in a dead context and
    // throw "root is not defined", swallowing the click. Defer the clear so the
    // click finishes before the delegates are replaced.
    function clearBadge(itemData) {
        if (!notifTracker) return
        Qt.callLater(function() {
            if (notifTracker) notifTracker.clearBadge(itemData)
        })
    }

    function doUpdateDockItems() {
        var toplevels = windowTracker.syncKnownWindows()
        var minTops = windowTracker.getMinimizedToplevels()
        var active = ToplevelManager.activeToplevel
        if (active) {
            if (minTops.indexOf(active) !== -1) {
                active = null
            } else if (typeof Hyprland !== "undefined" && Hyprland.activeToplevel && Hyprland.activeToplevel.workspace) {
                var aWs = String(Hyprland.activeToplevel.workspace.name || "")
                if (aWs.indexOf("special:") === 0) {
                    active = null
                }
            }
        }
        var lib = root.shell ? root.shell.appLibrary : null
        var allEntries = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values && DesktopEntries.applications.values.length > 0)
            ? DesktopEntries.applications.values
            : (lib && typeof lib.sortedEntries === "function" ? lib.sortedEntries("") : root.appRows)
        windowTracker.recordFocus(toplevels, active)
        var panelEntries = PluginPanels.entriesFor(root.barWidgetRegistry ? root.barWidgetRegistry.widgets : {}, function(id) {
            var hosted = null
            for (var i = 0; i < root.loadedWidgetItems.length; i++) {
                var item = root.loadedWidgetItems[i]
                if (item && item.moduleName === id) { hosted = item; break }
            }
            return root.getWidgetIcon(id, hosted)
        })
        root.dockItems = DockModel.buildDockItems(root.pinnedIds, toplevels, active, allEntries, lib, notifTracker.canonicalCounts, notifTracker.canonicalUrgent, root.maxDockItems, minTops, root.focusedWindowHistory, panelEntries)

        if (!root.isStackOpen) {
            root.drag.cancelFolder()
        }
    }

    onPinnedIdsChanged: updateDockItems()
    onAppRowsChanged: updateDockItems()
    onShellChanged: {
        root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
        root.updateDockItems()
    }

    Process {
        id: iconScannerProc
        running: false
        command: [Qt.resolvedUrl("bin/familiar-desktop").toString().replace(/^file:\/\//, ""), "dock", "scan-icons"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var icons = JSON.parse(text)
                    if (icons && typeof icons === "object" && icons.state !== "failed") {
                        DockModel.setDiskIcons(icons)
                        root.iconRevision++
                        root.updateDockItems()
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: iconScanDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!iconScannerProc.running) {
                iconScannerProc.running = true
            }
        }
    }

    Connections {
        target: Commons.Color
        function onAccentChanged() {
            if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
                shell.appLibrary.refreshIcons()
            }
            root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
            root.doUpdateDockItems()
        }
        function onForegroundChanged() { root.doUpdateDockItems() }
        function onBackgroundChanged() { root.doUpdateDockItems() }
    }

    Connections {
        target: Style
        function onCornerRadiusChanged() {
            root.doUpdateDockItems()
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : (DesktopEntries.applications.values || [])
            iconScanDebounceTimer.restart()
            root.iconRevision++
            root.updateDockItems()
        }
    }

    Connections {
        target: shell ? shell.appLibrary : null
        enabled: target !== null
        function onAppsChanged() {
            root.appRows = shell.appLibrary.sortedEntries("")
            root.iconRevision++
            root.updateDockItems()
        }
        function onIconIndexChanged() {
            root.iconRevision++
            root.doUpdateDockItems()
        }
    }

    FileView {
        id: themeWatcher
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
                shell.appLibrary.refreshIcons()
            }
            iconScanDebounceTimer.restart()
            root.appRows = (shell && shell.appLibrary) ? shell.appLibrary.sortedEntries("") : []
            root.iconRevision++
            root.doUpdateDockItems()
        }
    }

    property bool isGtkSettingsLoaded: false

    FileView {
        id: gtkSettingsFile
        path: Quickshell.env("HOME") + "/.config/gtk-3.0/settings.ini"
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.isGtkSettingsLoaded = true
            root.triggerThemeRefresh()
        }
        onFileChanged: {
            reload()
            root.isGtkSettingsLoaded = true
            root.triggerThemeRefresh()
        }
    }

    readonly property string configuredIconTheme: {
        var txt = gtkSettingsFile.text()
        if (!txt) return ""
        var m = txt.match(/gtk-icon-theme-name\s*=\s*([^\r\n]+)/)
        return m ? m[1].trim() : ""
    }

    readonly property bool hasCustomIconTheme: {
        var t = root.configuredIconTheme.toLowerCase()
        return t.length > 0 && t !== "hicolor" && t !== "adwaita" && t !== "gnome"
    }

    property bool isPinnedLoaded: false
    property bool iconsReady: false
    property bool isDockVisualReady: false

    function triggerThemeRefresh() {
        themeChangeDebounceTimer.restart()
    }

    Timer {
        id: themeChangeDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
                shell.appLibrary.refreshIcons()
            }
        }
    }

    Timer {
        id: iconIndexApplyTimer
        interval: 20
        repeat: false
        onTriggered: {
            root.iconRevision++
            root.doUpdateDockItems()
            var hasIndex = (shell && shell.appLibrary && shell.appLibrary.iconIndex && Object.keys(shell.appLibrary.iconIndex).length > 0)
            if (hasIndex) {
                root.iconsReady = true
            }
        }
    }

    FileView {
        id: omarchyIconThemeFile
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/icons.theme"
        watchChanges: true
        printErrors: false
        onFileChanged: root.triggerThemeRefresh()
        onLoaded: root.triggerThemeRefresh()
    }

    FileView {
        id: gtk4SettingsFile
        path: Quickshell.env("HOME") + "/.config/gtk-4.0/settings.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: root.triggerThemeRefresh()
        onLoaded: root.triggerThemeRefresh()
    }

    // Защитный таймер: если фоновый поиск темы затянулся, показываем доступные иконки
    Timer {
        id: iconsSafetyTimer
        interval: 1500
        running: !root.iconsReady
        repeat: false
        onTriggered: {
            if (!root.iconsReady) {
                root.iconRevision++
                root.doUpdateDockItems()
                root.iconsReady = true
            }
        }
    }

    // Задержка показа дока после поднятия плитки окон Hyprland (250мс на анимацию тайлинга и готовность иконок)
    Timer {
        id: dockVisualAppearTimer
        interval: 250
        running: root.iconsReady && !root.isDockVisualReady
        repeat: false
        onTriggered: {
            root.isDockVisualReady = true
        }
    }

    Connections {
        target: (shell && shell.appLibrary) ? shell.appLibrary : null
        function onIconIndexChanged() {
            iconIndexApplyTimer.restart()
        }
        function onAppsChanged() {
            iconIndexApplyTimer.restart()
        }
    }

    Component.onCompleted: {
        visibility.rememberBaseMonitor()
        root.parseShellConfigFile()
        taskbarController.run("status")
        try {
            var txt = userPinnedFile.text()
            if (txt && txt.trim().length > 0) {
                var parsed = DockModel.parsePinned(txt)
                if (parsed && parsed.length > 0) {
                    root.pinnedIds = parsed
                    root.isPinnedLoaded = true
                }
            }
        } catch(e) {}
        settings.reload()
        root.refreshHyprlandOptions()
        if (shell && shell.appLibrary && typeof shell.appLibrary.refreshIcons === "function") {
            shell.appLibrary.refreshIcons()
        }
        if (shell && shell.appLibrary && typeof shell.appLibrary.launch === "function" && !shell.appLibrary._dockLaunchHooked) {
            shell.appLibrary._dockLaunchHooked = true
            var origAppLibLaunch = shell.appLibrary.launch
            shell.appLibrary.launch = function(appId, appName) {
                root.requestFocusOnLaunch(appId)
                DockModel.setPendingCliHint(appId, root.knownWindows)
                return origAppLibLaunch.apply(this, arguments)
            }
        }
        iconScanDebounceTimer.restart()
        root.doUpdateDockItems()
    }

    FileView {
        id: userPinnedFile
        path: root.userPinnedPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            var txt = text()
            if (txt && txt.trim().length > 0) {
                var parsed = DockModel.parsePinned(txt)
                root.pinnedIds = parsed
                root.isPinnedLoaded = true
                root.doUpdateDockItems()
            } else {
                root.isPinnedLoaded = true
            }
        }
        onLoadFailed: {
            root.isPinnedLoaded = true
            root.doUpdateDockItems()
        }
        onFileChanged: userPinnedFile.reload()
    }

    function savePinned() {
        var json = DockModel.serializePinned(root.pinnedIds)
        userPinnedFile.setText(json + "\n")
    }

    function setPinned(next) {
        root.pinnedIds = next
        root.savePinned()
        root.doUpdateDockItems()
    }

    readonly property var activeToplevel: ToplevelManager.activeToplevel

    // 1. Outside-click dismissal for Context Menu (closes ONLY the menu)
    HyprlandFocusGrab {
        id: menuGrab
        active: root.isMenuOpen
        windows: [menuWindow]
        onCleared: {
            root.interaction.dismissFolderMenu()
        }
    }

    // 3. Outside-click & Escape dismissal for Edit Mode
    HyprlandFocusGrab {
        id: editGrab
        active: root.isEditMode && !root.isStackOpen && !root.isMenuOpen
        windows: root.taskbarActive && root.dockWindow ? [root.dockWindow] : dockVariants.instances
        onCleared: {
            root.interaction.setEditing(false)
        }
    }

    onIsEditModeChanged: {
        if (isEditMode) {
            var win = root.dockWindow
            if (win && win.surface) win.surface.forceActiveFocus()
        }
        root.evaluateHoverState()
    }

    onIsStackOpenChanged: {
        if (isStackOpen) {
            if (stackWindow && stackWindow.stackCard) stackWindow.stackCard.forceActiveFocus()
        }
        root.evaluateHoverState()
    }

    onIsMenuOpenChanged: root.evaluateHoverState()

    onIsEditingFolderTitleChanged: {
        root.evaluateHoverState()
    }

    readonly property var dockWindow: {
        if (root.taskbarActive && root.taskbarAnchorItem) return root.taskbarAnchorItem.QsWindow.window
        var instances = dockVariants.instances
        var count = instances ? instances.length : 0
        // When a reveal is targeting a specific (possibly non-focused) screen,
        // popups should attach to that revealed instance instead of whichever
        // screen has keyboard focus.
        var targetName = root.revealTargetMonitorName !== "" ? root.revealTargetMonitorName : ""
        if (targetName !== "") {
            for (var t = 0; t < count; t++) {
                var targetWin = instances[t]
                if (targetWin && targetWin.screen && String(targetWin.screen.name || "") === targetName)
                    return targetWin
            }
        }
        var focusedName = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
        for (var i = 0; i < count; i++) {
            var win = instances[i]
            if (win && win.screen && String(win.screen.name || "") === focusedName)
                return win
        }
        return count > 0 ? instances[0] : null
    }

    WindowPreviewController {
        id: windowPreview
        allowed: root.windowPreviews && root.dockMapped && root.dockRevealed
            && !root.isEditMode && root.dockDragActiveIndex < 0 && !root.isMenuOpen && !root.isStackOpen
            && (!dockBarContext.activePopout || dockBarContext.activePopout === windowPreview)
        onOpenedChanged: {
            if (!opened) dockBarContext.releasePopout(windowPreview)
            root.evaluateHoverState()
        }
    }
    Loader {
        active: windowPreview.opened
        sourceComponent: WindowPreviewPopup {
            controller: windowPreview
            bar: dockBarContext
            onWindowSelected: function(target) {
                var app = windowPreview.app
                var index = WindowPreviews.currentIndex(app, target)
                // Never activate a replacement window at an old list index.
                if (index >= 0 && root.targetWindowArg(app, index)) root.restoreOrLaunchItem(app, index)
                else if (index >= 0 && target && typeof target.activate === "function") target.activate()
                windowPreview.close()
            }
        }
    }

    // 1. The Main Solid Dock Window (One layer surface per output, matching Omarchy bar)
    Variants {
        id: dockVariants
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: dockLayer
                required property var modelData
                property alias surface: dockSurface
                property alias hoverHandler: dockHoverHandler
                // Per-screen slide state: this screen's own reveal state,
                // unless another screen is the current reveal target (in
                // which case this one stays/goes slid out even while
                // root.shouldSlideOut is false).
                readonly property bool slidOut: root.screenSlidesOut(modelData)
                screen: modelData
                visible: !root.taskbarHostedOn(modelData) && root.dockMapped && root.screenShowsDock(modelData) && !remapGuard.remapping

                ScreenMoveRemap {
                    id: remapGuard
                    window: dockLayer
                }

                WlrLayershell.namespace: "familiar-desktop-dock"
                // Fullscreen windows stack above the Top layer, which would
                // leave an autohidden dock unreachable exactly when it is
                // summoned. Overlay keeps it callable there. In "always" mode
                // the dock is permanently on screen, so it stays on Top and
                // lets fullscreen content win.
                WlrLayershell.layer: root.autohide ? WlrLayer.Overlay : WlrLayer.Top
                WlrLayershell.keyboardFocus: root.isEditMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                exclusionMode: root.dockRevealed && !dockLayer.slidOut && !root.overlayMode ? ExclusionMode.Auto : ExclusionMode.Ignore
                color: "transparent"
                surfaceFormat.opaque: false

                // Input region. While the dock is slid out its card is
                // translated off the window and the HoverHandler below is
                // disabled, so claiming the whole window there only swallows
                // the outer edge of whatever is underneath -- a fullscreen
                // client, since autohide puts this window on the Overlay layer
                // -- for a dock that cannot be hovered anyway. Revealing it is
                // the separate edge trigger's job. Hand the strip back.
                mask: DockInputRegion {
                    surface: dockSurface
                    translationX: autohideTranslate.x
                    translationY: autohideTranslate.y
                    hidden: dockLayer.slidOut
                }

                anchors {
                    top: root.dockLayout.anchors.top
                    bottom: root.dockLayout.anchors.bottom
                    left: root.dockLayout.anchors.left
                    right: root.dockLayout.anchors.right
                }

                margins {
                    top: root.dockLayout.margins.top
                    bottom: root.dockLayout.margins.bottom
                    left: root.dockLayout.margins.left
                    right: root.dockLayout.margins.right
                }

                // Hosted KeyboardPanel anchors use screen-relative coordinates along the bar.
                // Span that axis, but claim input only over the visible dock card.
                implicitWidth: root.isVertical ? (root.slotSize + 8) : modelData.width
                implicitHeight: root.isVertical ? modelData.height : (root.slotSize + 8)

                HoverHandler {
                    id: dockHoverHandler
                    enabled: root.autohide && !dockLayer.slidOut
                    onHoveredChanged: {
                        root.evaluateHoverState()
                    }
                }

                // Main Visual Dock Card
        Rectangle {
            id: dockSurface
            anchors.centerIn: parent
            width: root.dockSurfaceSize.width
            height: root.dockSurfaceSize.height
            visible: root.dockMapped
            opacity: root.isDockVisualReady ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            focus: root.isEditMode

            Keys.onEscapePressed: function(event) {
                event.accepted = true
                if (root.isEditingFolderTitle) {
                    root.interaction.renameFolder(false)
                    return
                }
                if (root.isStackOpen) {
                    root.interaction.dismissFolder()
                }
                root.interaction.setEditing(false)
            }

            color: root.dockBackgroundColor
            border.width: (Border.canUseNative(root.dockBorderSpec) && !root.dockBackgroundTransparent) ? Border.uniformWidth(root.dockBorderSpec) : 0
            border.color: (Border.canUseNative(root.dockBorderSpec) && !root.dockBackgroundTransparent) ? Border.color(root.dockBorderSpec) : "transparent"
            radius: root.systemRounding
            antialiasing: true
            smooth: true

            Loader {
                anchors.fill: parent
                active: !root.dockBackgroundTransparent && Border.needsOverlay(root.dockBorderSpec)
                sourceComponent: DockBorderOverlay {
                    anchors.fill: parent
                    radius: root.systemRounding
                    borderSpec: root.dockBorderSpec
                    animated: root.borderAngleAnimationEnabled
                    animationDuration: root.borderAngleAnimationDuration
                }
            }

            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
            Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
            Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: (root.dockDragActiveIndex >= 0) ? Qt.BlankCursor : (root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)
                onClicked: {
                    root.interaction.setEditing(false)
                    root.interaction.dismissFolderMenu()
                    root.interaction.dismissFolder()
                }
            }

            transform: Translate {
                id: autohideTranslate
                x: {
                    if (!dockLayer.slidOut) return 0
                    if (root.barPosition === "right") return -56
                    if (root.barPosition === "left") return 56
                    return 0
                }
                y: {
                    if (!dockLayer.slidOut) return 0
                    if (root.barPosition === "top") return 56
                    if (root.barPosition === "bottom") return -56
                    return 0
                }
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            Behavior on radius { NumberAnimation { duration: 200 } }

            Item {
                id: dockContent
                anchors.centerIn: parent
                width: root.isVertical ? root.slotSize : root.totalDockDimension
                height: root.isVertical ? root.totalDockDimension : root.slotSize

                PlacesShortcuts {
                    visible: root.fileShortcutsEnabled
                    vertical: root.isVertical
                    slotSize: root.slotSize
                    busy: root.desktopActionBusy
                    errorText: root.desktopActionError
                    x: root.isVertical ? 0 : root.totalDockDimension - root.fileShortcutsSize
                    y: root.isVertical ? root.totalDockDimension - root.fileShortcutsSize : 0
                    onOpenLocation: function(location) { root.desktopAction("open-location", location) }
                }
                // 1. Left Dock Active Bar/Tray Widgets
                Repeater {
                    model: root.leftWidgetsList

                    DockWidgetSlot {
                        actions: widgetActions
                        offset: root.getLeftWidgetOffset(index)
                        isVertical: root.isVertical
                        clockSlotWidth: root.clockSlotWidth
                        slotSize: root.slotSize
                        iconBaseSize: root.iconBaseSize
                        isEditMode: root.isEditMode
                        clockDisplayText: root.clockDisplayText
                        currentHourString: root.currentHourString
                        currentMinutePart: root.currentMinutePart
                        widgetIconRevision: root.widgetIconRevision
                        pipewireSinkVolume: root.pipewireSinkVolume
                        pipewireSinkMuted: root.pipewireSinkMuted
                        pipewireSourceMuted: root.pipewireSourceMuted
                        upowerBatteryPercentage: root.upowerBatteryPercentage
                        upowerBatteryState: root.upowerBatteryState
                        widgetRegistryRevision: root.widgetRegistryRevision
                        onClockUpdated: function(text) { root.clockDisplayText = text }
                    }
                }

                // 2. Left Sleek Separator between Left Widgets and Apps
                Item {
                    id: leftDockSeparator
                    visible: root.hasLeftWidgets
                    opacity: root.hasLeftWidgets ? 1.0 : 0.0
                    x: root.isVertical ? 0 : root.leftWidgetsWidth
                    y: root.isVertical ? root.leftWidgetsWidth : 0
                    width: root.isVertical ? root.slotSize : root.leftSeparatorSize
                    height: root.isVertical ? root.leftSeparatorSize : root.slotSize
                    z: 0

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.isVertical ? (root.slotSize - 18) : 1.5
                        height: root.isVertical ? 1.5 : (root.slotSize - 18)
                        radius: 0.75
                        color: Util.alpha(Commons.Color.bar.text, 0.25)
                    }
                }

                // 3. Applications & Folders
                Repeater {
                    model: root.dockItems

                    DockItem {
                        onPreviewHoverChanged: function(item, hovered) {
                            if (hovered) windowPreview.enter(item)
                            else windowPreview.leave(item)
                        }
                        onPreviewCancelled: windowPreview.close()
                        itemData: modelData
                        itemIndex: index
                        totalCount: root.dockItems.length
                        barPosition: root.barPosition
                        shell: root.shell
                        knownWindows: root.knownWindows
                        slotSize: root.slotSize
                        iconBaseSize: root.iconBaseSize
                        iconRevision: root.iconRevision
                        iconsReady: root.iconsReady
                        systemBorderSize: root.systemBorderSize
                        systemRounding: root.systemRounding
                        isSelected: (root.activeMenuItem && root.activeMenuItem.id === modelData.id) || (root.activeStackItem && root.activeStackItem.id === modelData.id)
                        isMergeTarget: (root.currentMergeTargetIndex === index)

                        // 1D Live Rail Displacement (with Left Widget offset)
                        readonly property real appBaseOffset: root.appRailOffset
                        readonly property int visualSlot: (root.dockDragActiveIndex === index) ? index : Drag.visualSlot(index, root.dockDragActiveIndex, root.dockDragTargetIndex)
                        x: root.isVertical ? 0 : (appBaseOffset + visualSlot * root.slotSize)
                        y: root.isVertical ? (appBaseOffset + visualSlot * root.slotSize) : 0

                        Behavior on x { enabled: root.dockDragActiveIndex >= 0; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on y { enabled: root.dockDragActiveIndex >= 0; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        isEditMode: root.isEditMode
                        showBadges: root.showBadges
                        dockDragActiveIndex: root.dockDragActiveIndex

                        onEditModeRequested: {
                            root.interaction.setEditing(true)
                            root.interaction.dismissFolderMenu()
                        }

                        onEditModeExitRequested: {
                            root.interaction.setEditing(false)
                        }

                        onTogglePinRequested: function(appId) {
                            root.setPinned(DockModel.togglePinned(root.pinnedIds, appId, root.maxDockItems))
                        }

                        onOriginalAppLaunched: function(appId) {
                            root.requestFocusOnLaunch(appId)
                        }

                        onRestoreOrLaunchRequested: function(item, targetIndex) {
                            root.restoreOrLaunchItem(item, targetIndex)
                        }

                        onMinimizeRequested: function(item, targetIndex) {
                            root.minimizeItem(item, targetIndex)
                        }

                        onDissolveRequested: function(stackId) {
                            root.setPinned(DockModel.dissolveStack(root.pinnedIds, stackId))
                            root.interaction.setEditing(false)
                        }

                        onItemLeftClicked: function(item) {
                            root.interaction.dismissApp()
                            if (item && !item.isStack) {
                                root.clearBadge(item)
                            }
                            if (item && item.isStack) {
                                root.toggleStack(item, index)
                            } else {
                                root.interaction.dismissFolder()
                                root.interaction.dismissFolderMenu()
                                if (root.isEditMode) return
                            }
                        }

                        onItemRightClicked: function(item, targetItem) {
                            if (root.isEditMode) {
                                root.interaction.setEditing(false)
                                return
                            }
                            if (item && item.isStack) {
                                root.toggleMenu(item, index)
                                return
                            }
                            if (item) {
                                root.toggleAppMenu(item, index)
                            }
                        }

                        onDragStarted: function(fromIdx) {
                            root.drag.startDock(fromIdx)
                        }

                        onDragHoverChanged: function(fromIdx, targetIdx, isMergeIntent) {
                            root.drag.hoverDock(fromIdx, targetIdx, isMergeIntent)
                        }

                        onDragEnded: function() {
                            root.drag.cancelDock()
                        }

                        onMoveRequested: function(fromIdx, toIdx) {
                            root.drag.cancelDock()
                            root.setPinned(DockModel.reorderPinned(root.pinnedIds, root.dockItems, fromIdx, toIdx))
                        }

                        onMergeRequested: function(fromIdx, targetIdx) {
                            root.drag.cancelDock()
                            root.setPinned(DockModel.mergeIntoStack(root.pinnedIds, root.dockItems, fromIdx, targetIdx, root.appRows))
                        }
                    }
                }

                // 4. Right Sleek Separator between Apps and Right Widgets
                Item {
                    id: rightDockSeparator
                    visible: root.hasRightWidgets
                    opacity: root.hasRightWidgets ? 1.0 : 0.0
                    readonly property real rSepOffset: (root.hasLeftWidgets ? (root.leftWidgetsWidth + root.leftSeparatorSize) : 0) + root.itemsWidth
                    x: root.isVertical ? 0 : rSepOffset
                    y: root.isVertical ? rSepOffset : 0
                    width: root.isVertical ? root.slotSize : root.rightSeparatorSize
                    height: root.isVertical ? root.rightSeparatorSize : root.slotSize
                    z: 0

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.isVertical ? (root.slotSize - 18) : 1.5
                        height: root.isVertical ? 1.5 : (root.slotSize - 18)
                        radius: 0.75
                        color: Util.alpha(Commons.Color.bar.text, 0.25)
                    }
                }

                // 5. Right Dock Active Bar/Tray Widgets
                Repeater {
                    model: root.rightWidgetsList

                    DockWidgetSlot {
                        actions: widgetActions
                        offset: (root.hasLeftWidgets ? root.leftWidgetsWidth + root.leftSeparatorSize : 0) + root.itemsWidth + root.rightSeparatorSize + root.getRightWidgetOffset(index)
                        isVertical: root.isVertical
                        clockSlotWidth: root.clockSlotWidth
                        slotSize: root.slotSize
                        iconBaseSize: root.iconBaseSize
                        isEditMode: root.isEditMode
                        clockDisplayText: root.clockDisplayText
                        currentHourString: root.currentHourString
                        currentMinutePart: root.currentMinutePart
                        widgetIconRevision: root.widgetIconRevision
                        pipewireSinkVolume: root.pipewireSinkVolume
                        pipewireSinkMuted: root.pipewireSinkMuted
                        pipewireSourceMuted: root.pipewireSourceMuted
                        upowerBatteryPercentage: root.upowerBatteryPercentage
                        upowerBatteryState: root.upowerBatteryState
                        widgetRegistryRevision: root.widgetRegistryRevision
                        onClockUpdated: function(text) { root.clockDisplayText = text }
                    }
                }
            }
        }
    }
    }
    }

    // 2. The Isolated Action Card Popup Overlay Window (Folder Icon Picker)
    FolderMenu {
        id: menuWindow
        interaction: root.interaction
        placement: root.folderPopupLayout
        appearance: root.popupAppearance
        revealed: root.dockRevealed
        icons: root.availableFolderIcons
        dockWindow: root.dockWindow
        onHoverChanged: function(hovered) { root.isMenuHovered = hovered; root.evaluateHoverState() }
        onIconChosen: function(id, icon) { root.setPinned(DockModel.setStackIcon(root.pinnedIds, id, icon)) }
        onDissolveRequested: function(id) { root.setPinned(DockModel.dissolveStack(root.pinnedIds, id)) }
    }

    AppMenu {
        root: root
        dockWindow: root.dockWindow
    }

    // 3. macOS Stacks Folder Grid Overlay Window (Folder Contents Popup)
    FolderPopup {
        id: stackWindow
        root: root
        dockWindow: root.dockWindow
    }

    // 4. Widget Picker Popup Menu
    WidgetPickerPopup {
        id: widgetPicker
        root: root
        dockWindow: root.dockWindow
        shell: root.shell
    }

    // 5. Autohide Edge Trigger — thin invisible strip at screen edge, activates dock reveal
    //    Recreate its input handler after each reveal so stale hover state cannot block re-arming.
    Variants {
        id: edgeVariants
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: edgeTriggerWindow
                required property var modelData
                screen: modelData
                visible: !root.taskbarActive && root.dockAvailable
                         && (root.visibilityMode === "hover" || root.visibilityMode === "hybrid")
                         && root.screenSlidesOut(modelData)
                         && root.screenShowsDock(modelData)

                WlrLayershell.namespace: "familiar-desktop-dock-edge"
                // The reveal trigger only exists while autohide is on, and it
                // has to catch the pointer over a fullscreen window.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region { item: edgeTriggerLoader }

                // Anchor to the same edge as the dock, no margins — hug the screen edge
                anchors {
                    top: root.edgeLayout.anchors.top
                    bottom: root.edgeLayout.anchors.bottom
                    left: root.edgeLayout.anchors.left
                    right: root.edgeLayout.anchors.right
                }

                margins {
                    top: 0
                    bottom: 0
                    left: 0
                    right: 0
                }

                implicitWidth:  root.isVertical ? root.effectiveAutohideEdgeDepth : Math.max(root.slotSize + 8, root.totalDockDimension + 14)
                implicitHeight: root.isVertical ? Math.max(root.slotSize + 8, root.totalDockDimension + 14) : root.effectiveAutohideEdgeDepth

                Loader {
                    id: edgeTriggerLoader
                    anchors.fill: parent
                    active: edgeTriggerWindow.visible

                    sourceComponent: Component {
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                visibility.edgeReveal(edgeTriggerWindow.modelData ? edgeTriggerWindow.modelData.name : "")
                            }
                        }
                    }
                }
            }
        }
    }
}
