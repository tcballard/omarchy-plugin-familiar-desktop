import QtQuick
import QtTest
import "../components"

TestCase {
    name: "DockDragState"
    DockDragState { id: drag }
    function init() { drag.cancel() }
    function test_reorderAndMergeAreExclusive() {
        drag.startDock(1)
        drag.hoverDock(1, 3, false)
        compare(drag.dockTarget, 3)
        compare(drag.mergeTarget, -1)
        drag.hoverDock(1, 2, true)
        compare(drag.dockTarget, -1)
        compare(drag.mergeTarget, 2)
        drag.hoverDock(-1, 2, true)
        compare(drag.dockIndex, -1)
        compare(drag.mergeTarget, -1)
    }
    function test_folderCancellationKeepsDockDrag() {
        drag.hoverDock(2, 3, true)
        drag.startFolder(0)
        drag.hoverFolder(1)
        drag.cancelFolder()
        compare(drag.folderIndex, -1)
        compare(drag.folderTarget, -1)
        compare(drag.dockIndex, 2)
        compare(drag.mergeTarget, 3)
        drag.clearMerge()
        compare(drag.mergeTarget, -1)
    }
    function test_lifecycleCancellationClearsBothSurfaces() {
        drag.hoverDock(2, 0, false)
        drag.startFolder(3)
        drag.hoverFolder(1)
        drag.cancel()
        compare(drag.dockIndex, -1)
        compare(drag.dockTarget, -1)
        compare(drag.mergeTarget, -1)
        compare(drag.folderIndex, -1)
        compare(drag.folderTarget, -1)
    }
}
