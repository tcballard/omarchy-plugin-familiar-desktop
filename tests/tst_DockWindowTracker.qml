import QtQuick
import QtTest
import "../components"
import "../DockModel.js" as DockModel

TestCase {
    name: "DockWindowTracker"
    QtObject { id: first; property string appId: "editor" }
    QtObject { id: second; property string appId: "browser" }
    QtObject { id: third; property string appId: "foot" }
    QtObject { id: tops; property var values: [] }
    QtObject { id: manager; property var toplevels: tops; property var activeToplevel: null }
    QtObject { id: spaces; property var values: [] }
    QtObject {
        id: hypr
        property var workspaces: spaces
        property var activeToplevel: null
        signal rawEvent(var event)
    }
    DockWindowTracker { id: tracker; toplevelManager: manager; hyprland: hypr }
    SignalSpy { id: refreshes; target: tracker; signalName: "refreshRequested" }
    SignalSpy { id: icons; target: tracker; signalName: "iconRefreshRequested" }
    SignalSpy { id: focuses; target: tracker; signalName: "focusRequested" }
    function init() {
        tops.values = []
        manager.activeToplevel = null
        spaces.values = []
        tracker.knownWindows = []
        tracker.focusedWindowHistory = []
        tracker.pendingFocusAppId = ""
        tracker.lastWindowOpenTime = 0
        tracker.lastTerminalOpenTime = 0
        findChild(tracker, "cli-scanner").running = false
        refreshes.clear(); icons.clear(); focuses.clear()
    }
    function cleanup() {
        tracker.lastTerminalOpenTime = 0
        DockModel.setDetectedCliApps([])
    }
    function test_creationOrderAndImmediateFocusHistory() {
        tops.values = [first, second]
        compare(tracker.syncKnownWindows(), [first, second])
        manager.activeToplevel = second
        compare(tracker.focusedWindowHistory, [second])
        tops.values = [third, second, first]
        compare(tracker.syncKnownWindows(), [first, second, third])
        manager.activeToplevel = first
        compare(tracker.focusedWindowHistory, [first, second])
        tops.values = [third, second]
        compare(tracker.syncKnownWindows(), [second, third])
        tracker.recordFocus(tops.values, manager.activeToplevel)
        compare(tracker.focusedWindowHistory, [second])
    }
    function test_minimizedWindowsAndWorkspaceLabels() {
        var hyprTop = {wayland: first}
        spaces.values = [{name: "special:minimized", toplevels: {values: [hyprTop]}}]
        compare(tracker.getMinimizedToplevels(), [first, hyprTop])
        compare(tracker.windowLocation(first), "Minimised")
        spaces.values = [{name: "2", toplevels: {values: [second]}}]
        compare(tracker.windowLocation(second), "Workspace 2")
        compare(tracker.windowLocation(first), "Workspace unavailable")
    }
    function test_launchFocusUsesValidatedAddressAndExpires() {
        tracker.requestFocusOnLaunch("editor.desktop")
        hypr.rawEvent({name: "openwindow", args: "abc,1,editor,Document"})
        compare(focuses.signalArguments[0][0], "0xabc")
        compare(tracker.pendingFocusAppId, "")
        compare(icons.count, 1)
        tracker.requestFocusOnLaunch("editor")
        hypr.rawEvent({name: "openwindow", args: "invalid,1,editor,Document"})
        compare(focuses.count, 1)
        tracker.requestFocusOnLaunch("editor")
        tracker.pendingFocusTimestamp = Date.now() - 9000
        hypr.rawEvent({name: "openwindow", args: "def,1,editor,Document"})
        compare(focuses.count, 1)
        compare(tracker.pendingFocusAppId, "")
    }
    function test_terminalSettlingAndScannerResults() {
        tops.values = [third]
        var scanner = findChild(tracker, "cli-scanner")
        verify(scanner.running)
        verify(scanner.command[0].endsWith("/bin/familiar-desktop"))
        compare(scanner.command.slice(1), ["dock", "scan-cli"])
        refreshes.clear()
        scanner.complete('["yazi"]', 0)
        compare(refreshes.count, 1)
        scanner.complete('{"state":"failed"}', 1)
        compare(refreshes.count, 1, "a failed helper response never becomes a model snapshot")
        tracker.lastTerminalOpenTime = 0
        tracker.refreshSoon()
        tryCompare(refreshes, "count", 2, 300)
    }
}
