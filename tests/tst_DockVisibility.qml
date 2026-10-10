import QtQuick
import QtTest
import "../components"

TestCase {
    id: test
    name: "DockVisibility"
    QtObject { id: aWindows; property var values: ["a"] }
    QtObject { id: bWindows; property var values: ["b"] }
    property var screenA: ({name: "A"})
    property var screenB: ({name: "B"})
    QtObject { id: monitorA; property string name: "A"; property var activeWorkspace: test.workspaceA }
    QtObject { id: monitorB; property string name: "B"; property var activeWorkspace: test.workspaceB }
    property var workspaceA: ({id: 1, name: "1", monitor: monitorA, toplevels: aWindows})
    property var workspaceB: ({id: 2, name: "2", monitor: monitorB, toplevels: bWindows})
    QtObject { id: spaces; property var values: [test.workspaceA, test.workspaceB] }
    QtObject { id: tops; property var values: [] }
    QtObject { id: manager; property var toplevels: tops }
    QtObject {
        id: hypr
        property var workspaces: spaces
        property var focusedMonitor: monitorA
        property var focusedWorkspace: test.workspaceA
        signal rawEvent(var event)
        function monitorFor(screen) { return screen.name === "A" ? monitorA : monitorB }
    }
    property bool widgetOpen: false
    DockVisibility {
        id: visibility
        hyprland: hypr
        toplevelManager: manager
        screens: [test.screenA, test.screenB]
        available: true
        widgetPanelsOpen: function() { return test.widgetOpen }
    }
    SignalSpy { id: closes; target: visibility; signalName: "closePopupsRequested" }
    function init() {
        spaces.values = [workspaceA, workspaceB]
        aWindows.values = ["a"]; bWindows.values = ["b"]
        hypr.focusedMonitor = monitorA
        hypr.focusedWorkspace = workspaceA
        visibility.screens = [screenA, screenB]
        visibility.mode = "always"
        visibility.workspaceSelector = "all"
        visibility.available = true
        visibility.remapping = false
        visibility.taskbarActive = false
        visibility.dockSurfaces = []
        visibility.popupHovered = false
        visibility.interactionActive = false
        visibility.dragActive = false
        widgetOpen = false
        visibility.overrideMode = 0
        visibility.hovered = false
        visibility.revealMonitorName = ""
        visibility.lastToggleRevealTime = 0
        visibility.rememberBaseMonitor()
        visibility.cancelLeave()
        visibility.refreshWindowCount()
        closes.clear()
    }
    function test_monitorAndWorkspaceSelection() {
        verify(visibility.revealed)
        verify(visibility.screenShowsDock(screenA))
        verify(visibility.screenShowsDock(screenB))
        compare(visibility.effectiveScreen, screenA)
        visibility.workspaceSelector = "2"
        compare(visibility.effectiveScreen, screenB)
        compare(visibility.currentWorkspace, workspaceB)
        compare(visibility.screenShowsDock(screenA), false)
        verify(visibility.screenShowsDock(screenB))
        visibility.remapping = true
        compare(visibility.mapped, false)
        visibility.remapping = false
        visibility.workspaceSelector = "all"
        hypr.focusedMonitor = monitorB
        compare(visibility.effectiveScreen, screenB)
        visibility.screens = [screenA]
        compare(visibility.effectiveScreen, screenA, "missing focused output falls back to the base output")
    }
    function test_edgeRevealAndPopupInactivity() {
        visibility.mode = "hover"
        compare(visibility.revealed, false)
        visibility.edgeReveal("B")
        verify(visibility.revealed)
        verify(visibility.screenSlidesOut(screenA))
        compare(visibility.screenSlidesOut(screenB), false)
        visibility.interactionActive = true
        visibility.evaluateHoverState()
        wait(1600)
        verify(visibility.revealed, "an open menu holds the reveal")
        visibility.interactionActive = false
        visibility.evaluateHoverState()
        tryCompare(visibility, "revealed", false, 1800)
        verify(closes.count > 0)
    }
    function test_keyboardPermissionsAndDebounce() {
        visibility.mode = "hover"
        compare(visibility.toggleReveal(), "inactive")
        visibility.mode = "hybrid"
        compare(visibility.toggleReveal(), "shown")
        compare(visibility.toggleReveal(), "shown", "a repeated shortcut is debounced")
        visibility.lastToggleRevealTime = 0
        compare(visibility.toggleReveal(), "hidden")
        visibility.mode = "keybind"
        aWindows.values = []
        hypr.rawEvent({name: "closewindow"})
        compare(visibility.revealed, false, "empty workspaces do not bypass keybind mode")
        visibility.available = false
        compare(visibility.toggleReveal(), "unavailable")
    }
    function test_emptyWorkspaceAndTaskbarVisibility() {
        visibility.mode = "hover"
        aWindows.values = []
        hypr.rawEvent({name: "closewindow"})
        compare(visibility.activeWindowCount, 0)
        verify(visibility.revealed)
        aWindows.values = ["a"]
        hypr.rawEvent({name: "openwindow"})
        compare(visibility.revealed, false)
        visibility.taskbarActive = true
        verify(visibility.revealed)
    }
    function test_widgetPickerRestoresOnlyItsOwnOverride() {
        visibility.mode = "hover"
        visibility.overrideMode = -1
        verify(visibility.prepareWidgetPicker())
        compare(visibility.overrideMode, 1)
        visibility.widgetPickerOpenedChanged(true)
        visibility.widgetPickerOpenedChanged(false)
        compare(visibility.overrideMode, -1)
        visibility.mode = "always"
        visibility.lastToggleRevealTime = 0
        verify(visibility.prepareWidgetPicker())
        compare(visibility.widgetPickerRevealOwned, false)
        visibility.widgetPickerOpenedChanged(false)
        compare(visibility.overrideMode, 0)
    }
    function test_losingConfiguredWorkspaceClosesItsReveal() {
        visibility.workspaceSelector = "2"
        visibility.overrideMode = 1
        spaces.values = [workspaceA]
        compare(visibility.workspaceAllowed, false)
        compare(visibility.dockAvailable, false)
        compare(visibility.overrideMode, -1)
        verify(closes.count > 0)
    }
}
