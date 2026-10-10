import QtQuick
import "../DockSettings.js" as DockSettings

// Owns session reveal state. Surfaces supply hover inputs and request actions.
Item {
    id: visibility
    required property var hyprland
    required property var toplevelManager
    required property var screens
    property string mode: "always"
    property string workspaceSelector: "all"
    property bool available: false
    property bool remapping: false
    property bool taskbarActive: false
    property var dockSurfaces: []
    property bool popupHovered: false
    property bool interactionActive: false
    property bool dragActive: false
    property var widgetPanelsOpen: function() { return false }
    property int overrideMode: DockSettings.VISIBILITY_OVERRIDE_FOLLOW
    property bool hovered: false
    property string revealMonitorName: ""
    property string baseMonitorName: ""
    property bool widgetPickerRevealOwned: false
    property int widgetPickerPreviousOverride: DockSettings.VISIBILITY_OVERRIDE_FOLLOW
    property double lastToggleRevealTime: 0
    signal closePopupsRequested()

    readonly property bool autohide: mode !== "always"
    readonly property bool hasExplicitWorkspace: workspaceSelector !== "all"
    readonly property var configuredWorkspace: hasExplicitWorkspace ? workspaceForSelector(workspaceSelector) : null
    readonly property string screenTarget: DockSettings.dockScreenTarget(workspaceSelector, mode, overrideMode)
    readonly property var effectiveScreen: {
        if (screenTarget === "configured" && configuredWorkspace && configuredWorkspace.monitor) {
            var configured = screenForMonitor(configuredWorkspace.monitor)
            if (configured) return configured
        }
        if (screenTarget === "all") {
            var focused = screenForMonitor(hyprland.focusedMonitor)
            if (focused) return focused
        }
        return screenForMonitorName(baseMonitorName) || (screens.length ? screens[0] : null)
    }
    readonly property var currentWorkspace: {
        if (hasExplicitWorkspace) return configuredWorkspace
        var monitor = effectiveScreen ? hyprland.monitorFor(effectiveScreen) : hyprland.focusedMonitor
        return monitor && monitor.activeWorkspace ? monitor.activeWorkspace : hyprland.focusedWorkspace
    }
    readonly property bool workspaceAllowed: !hasExplicitWorkspace || currentWorkspace !== null
    readonly property bool dockAvailable: available && workspaceAllowed
    readonly property bool mapped: dockAvailable && !remapping
    readonly property bool active: hovered || popupHovered || interactionActive || widgetPanelsOpen() || dragActive
    property int activeWindowCount: countWorkspaceWindows()
    readonly property bool shouldSlideOut: DockSettings.shouldSlideOut(mode, overrideMode, active, activeWindowCount === 0)
    readonly property bool revealed: dockAvailable && (taskbarActive || !shouldSlideOut)
    readonly property string revealTargetMonitorName: DockSettings.screenRevealTarget(mode, workspaceSelector,
        revealMonitorName, hyprland.focusedMonitor ? String(hyprland.focusedMonitor.name || "") : "")

    function workspaceForSelector(selector) {
        var normalized = DockSettings.normalizeVisibleWorkspace(selector)
        var workspaces = hyprland.workspaces && hyprland.workspaces.values ? hyprland.workspaces.values : []
        for (var i = 0; i < workspaces.length; i++) {
            var workspace = workspaces[i]
            if (workspace && DockSettings.workspaceMatches(normalized, workspace.id, workspace.name)) return workspace
        }
        return null
    }
    function screenForMonitorName(name) {
        if (!name) return null
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] && String(screens[i].name || "") === String(name)) return screens[i]
        }
        return null
    }
    function screenForMonitor(monitor) { return monitor ? screenForMonitorName(monitor.name) : null }
    function screenShowsDock(screen) {
        return !!screen && DockSettings.screenShowsDock(screenTarget, screen.name,
            configuredWorkspace && configuredWorkspace.monitor ? configuredWorkspace.monitor.name : "", "",
            hyprland.focusedMonitor ? hyprland.focusedMonitor.name : "")
    }
    function screenSlidesOut(screen) {
        return DockSettings.screenSlidesOut(shouldSlideOut, revealTargetMonitorName, screen ? screen.name : "")
    }
    function rememberBaseMonitor() {
        if (hyprland.focusedMonitor) baseMonitorName = String(hyprland.focusedMonitor.name || "")
    }
    function anySurfaceHovered() {
        for (var i = 0; i < dockSurfaces.length; i++) {
            var handler = dockSurfaces[i] ? dockSurfaces[i].hoverHandler : null
            if (handler && handler.hovered) return true
        }
        return false
    }
    function countWorkspaceWindows() {
        return currentWorkspace && currentWorkspace.toplevels && currentWorkspace.toplevels.values
            ? currentWorkspace.toplevels.values.length : 0
    }
    function refreshWindowCount() { activeWindowCount = countWorkspaceWindows() }
    function interactionHeld() { return popupHovered || interactionActive || widgetPanelsOpen() }
    function evaluateHoverState() {
        if (!autohide) return
        if ((!shouldSlideOut && anySurfaceHovered()) || interactionHeld()) {
            leaveTimer.stop()
            hovered = true
        } else leaveTimer.restart()
    }
    function cancelLeave() { leaveTimer.stop() }
    function clearHover() { hovered = false }
    function edgeReveal(monitorName) {
        if (overrideMode === DockSettings.VISIBILITY_OVERRIDE_HIDDEN) overrideMode = DockSettings.VISIBILITY_OVERRIDE_FOLLOW
        revealMonitorName = String(monitorName || "")
        hovered = true
        leaveTimer.restart()
    }
    function toggleReveal(source) {
        if (!available) return "unavailable"
        if (!DockSettings.revealRequestAllowed(mode, source === "internal" ? "internal" : "keyboard")) return "inactive"
        var now = Date.now()
        if (now - lastToggleRevealTime < 300) return revealed ? "shown" : "hidden"
        lastToggleRevealTime = now
        leaveTimer.stop()
        if (revealed) {
            overrideMode = DockSettings.VISIBILITY_OVERRIDE_HIDDEN
            hovered = false
            closePopupsRequested()
            return "hidden"
        }
        revealMonitorName = hyprland.focusedMonitor ? String(hyprland.focusedMonitor.name || "") : ""
        overrideMode = DockSettings.VISIBILITY_OVERRIDE_SHOWN
        hovered = true
        return "shown"
    }
    function prepareWidgetPicker() {
        widgetPickerRevealOwned = false
        widgetPickerPreviousOverride = overrideMode
        if (!revealed) {
            if (toggleReveal("internal") !== "shown") return false
            widgetPickerRevealOwned = true
        }
        return true
    }
    function widgetPickerOpenedChanged(opened) {
        if (opened) { leaveTimer.stop(); return }
        overrideMode = DockSettings.releaseInteractionVisibilityOverride(widgetPickerRevealOwned, widgetPickerPreviousOverride, overrideMode)
        widgetPickerRevealOwned = false
        hovered = false
        evaluateHoverState()
    }
    function resetReveal() {
        overrideMode = DockSettings.VISIBILITY_OVERRIDE_FOLLOW
        revealMonitorName = ""
    }
    onModeChanged: {
        widgetPickerRevealOwned = false
        resetReveal()
        hovered = false
        leaveTimer.stop()
    }
    onWorkspaceSelectorChanged: resetReveal()
    onRevealedChanged: {
        if (!revealed) { closePopupsRequested(); revealMonitorName = "" }
    }
    onWorkspaceAllowedChanged: {
        if (!workspaceAllowed && overrideMode === DockSettings.VISIBILITY_OVERRIDE_SHOWN) {
            overrideMode = DockSettings.VISIBILITY_OVERRIDE_HIDDEN
            closePopupsRequested()
        }
    }
    Timer {
        id: leaveTimer
        interval: 1500
        onTriggered: {
            if (!visibility.autohide || visibility.anySurfaceHovered() || visibility.interactionHeld()) return
            visibility.hovered = false
            if (DockSettings.shouldAutoDismissKeyboardReveal(visibility.mode, visibility.overrideMode))
                visibility.overrideMode = DockSettings.VISIBILITY_OVERRIDE_FOLLOW
        }
    }
    Connections {
        target: visibility.hyprland
        function onFocusedWorkspaceChanged() { visibility.refreshWindowCount() }
        function onRawEvent(event) { visibility.refreshWindowCount() }
    }
    Connections {
        target: visibility.hyprland.workspaces
        function onValuesChanged() { visibility.refreshWindowCount() }
    }
    Connections {
        target: visibility.toplevelManager.toplevels
        function onValuesChanged() { visibility.refreshWindowCount() }
    }
    Timer {
        interval: 200
        running: DockSettings.hasHover(visibility.mode) && visibility.workspaceAllowed
        repeat: true
        onTriggered: visibility.refreshWindowCount()
    }
}
