import QtQuick
import "../DockScroll.js" as DockScroll

// Shared app behavior; each surface keeps its own visuals and drag gestures.
Item {
    id: interaction
    property var itemData: null
    property bool hovered: false
    property int previewIndex: -1
    property bool cycling: false
    property real pendingScroll: 0
    readonly property bool isApp: !!itemData && !itemData.isStack
    readonly property int windowCount: isApp && itemData.toplevels ? itemData.toplevels.length : 0
    readonly property bool canCycle: isApp && !!itemData.isRunning && windowCount >= 2
    readonly property int activeIndex: isApp && typeof itemData.activeTopIndex === "number" ? itemData.activeTopIndex : 0
    readonly property int effectiveIndex: windowCount === 0 ? 0
        : previewIndex >= 0 && previewIndex < windowCount ? previewIndex : activeIndex
    signal feedbackRequested()
    signal launchRequested(var item)
    signal restoreRequested(var item, int index)

    Timer { id: scrollReset; interval: 180; onTriggered: interaction.pendingScroll = 0 }
    Timer { id: cursorReset; interval: 1200; onTriggered: interaction.cycling = false }
    Timer {
        id: previewReset
        interval: 1500
        onTriggered: if (!interaction.hovered) interaction.previewIndex = -1
    }

    function cycle(forward) {
        if (!canCycle) return false
        cycling = true
        cursorReset.restart()
        previewReset.stop()
        previewIndex = (effectiveIndex + (forward ? 1 : windowCount - 1)) % windowCount
        return true
    }
    function wheel(pixelX, pixelY, angleX, angleY) {
        if (!canCycle) return false
        var result = DockScroll.step(pendingScroll, pixelX, pixelY, angleX, angleY)
        pendingScroll = result.pending
        scrollReset.restart()
        if (result.direction !== 0) cycle(result.direction > 0)
        return true
    }
    function leave() { cycling = false; previewReset.restart() }
    function pointerMoved() { cycling = false }
    function launch() {
        if (!isApp) return false
        feedbackRequested()
        launchRequested(itemData)
        return true
    }
    function restore() {
        if (!isApp) return false
        var index = previewIndex >= 0 && previewIndex < windowCount ? previewIndex
            : windowCount >= 2 && itemData.isActive ? (activeIndex + 1) % windowCount : activeIndex
        previewIndex = -1
        restoreRequested(itemData, index)
        return true
    }
    function confirmPreview() {
        if (!canCycle || previewIndex < 0 || previewIndex >= windowCount) return false
        var top = itemData.toplevels[previewIndex]
        if (!top || typeof top.activate !== "function") return false
        previewIndex = -1
        top.activate()
        return true
    }
    onItemDataChanged: {
        // Read the new item here: derived bindings may still hold the old count
        // while its change handler is running.
        var count = itemData && !itemData.isStack && itemData.toplevels ? itemData.toplevels.length : 0
        if (!itemData || !itemData.isRunning || count < 2 || previewIndex >= count) {
            previewIndex = -1
            cycling = false
        }
    }
}
