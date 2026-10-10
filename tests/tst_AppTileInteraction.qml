import QtQuick
import QtTest
import "../components"

TestCase {
    name: "AppTileInteraction"
    QtObject { id: first; property int activations: 0; function activate() { activations++ } }
    QtObject { id: second; property int activations: 0; function activate() { activations++ } }
    QtObject { id: third; property int activations: 0; function activate() { activations++ } }
    AppTileInteraction { id: tile }
    SignalSpy { id: restores; target: tile; signalName: "restoreRequested" }
    SignalSpy { id: launches; target: tile; signalName: "launchRequested" }
    SignalSpy { id: feedback; target: tile; signalName: "feedbackRequested" }
    function app(windows, active, running) {
        return {appId: "editor", desktopId: "exact.editor.desktop", isRunning: running === undefined ? true : running,
            isActive: active, activeTopIndex: 1, toplevels: windows}
    }
    function init() {
        tile.itemData = null
        tile.previewIndex = -1
        tile.pendingScroll = 0
        tile.cycling = false
        tile.hovered = false
        first.activations = 0; second.activations = 0; third.activations = 0
        restores.clear(); launches.clear(); feedback.clear()
    }
    function test_clickSelectsNextActiveOrExplicitPreview() {
        var item = app([first, second, third], true)
        tile.itemData = item
        verify(tile.restore())
        compare(restores.signalArguments[0][0], item)
        compare(restores.signalArguments[0][1], 2)
        verify(tile.cycle(false))
        compare(tile.previewIndex, 0)
        verify(tile.restore())
        compare(restores.signalArguments[1][1], 0)
        compare(tile.previewIndex, -1)
        tile.itemData = app([first, second, third], false)
        verify(tile.restore())
        compare(restores.signalArguments[2][1], 1)
    }
    function test_cyclesWrapAndReturnActivatesTheSameWindow() {
        tile.itemData = app([first, second, third], false)
        verify(tile.cycle(true))
        compare(tile.effectiveIndex, 2)
        verify(tile.cycle(true))
        compare(tile.effectiveIndex, 0)
        verify(tile.cycle(false))
        compare(tile.effectiveIndex, 2)
        verify(tile.confirmPreview())
        compare(third.activations, 1)
        compare(first.activations, 0)
        compare(second.activations, 0)
        compare(tile.previewIndex, -1)
    }
    function test_smoothWheelAccumulatesForBothSurfaces() {
        tile.itemData = app([first, second, third], false)
        for (var i = 0; i < 7; i++) {
            verify(tile.wheel(0, 0, 0, -15))
            compare(tile.previewIndex, -1)
        }
        verify(tile.wheel(0, 0, 0, -15))
        compare(tile.previewIndex, 2)
        verify(tile.wheel(0, 0, 0, 120))
        compare(tile.previewIndex, 1)
        tile.pointerMoved()
        compare(tile.cycling, false)
    }
    function test_launchKeepsExactItemAndSingleWindowSkipsCycling() {
        var item = app([first], false)
        tile.itemData = item
        verify(tile.launch())
        compare(launches.signalArguments[0][0], item)
        compare(feedback.count, 1)
        compare(tile.cycle(true), false)
        compare(tile.wheel(0, 0, 0, 120), false)
        compare(tile.confirmPreview(), false)
        tile.itemData = {isStack: true}
        compare(tile.launch(), false)
        compare(tile.restore(), false)
        compare(launches.count, 1)
    }
    function test_removedWindowsClearStaleSelection() {
        tile.itemData = app([first, second, third], false)
        tile.cycle(true)
        compare(tile.previewIndex, 2)
        tile.itemData = app([first, second], false)
        compare(tile.previewIndex, -1)
        compare(tile.effectiveIndex, 1)
        tile.itemData = null
        compare(tile.effectiveIndex, 0)
        compare(tile.restore(), false)
    }
    function test_hoverProtectsPreviewAndLeavingExpiresIt() {
        tile.itemData = app([first, second, third], false)
        tile.cycle(true)
        tile.hovered = true
        tile.leave()
        wait(1600)
        compare(tile.previewIndex, 2)
        tile.hovered = false
        tile.leave()
        compare(tile.cycling, false)
        tryCompare(tile, "previewIndex", -1, 1800)
    }
}
