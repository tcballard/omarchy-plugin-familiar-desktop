import QtQuick

QtObject {
    id: state
    property int dockIndex: -1
    property int dockTarget: -1
    property int mergeTarget: -1
    property int folderIndex: -1
    property int folderTarget: -1

    function startDock(index) { dockIndex = index }
    function hoverDock(index, target, merge) {
        if (index < 0) { cancelDock(); return }
        dockIndex = index
        dockTarget = target >= 0 && !merge ? target : -1
        mergeTarget = target >= 0 && merge ? target : -1
    }
    function cancelDock() {
        dockIndex = -1
        dockTarget = -1
        mergeTarget = -1
    }
    function startFolder(index) { folderIndex = index }
    function hoverFolder(index) { folderTarget = index }
    function cancelFolder() {
        folderIndex = -1
        folderTarget = -1
    }
    function clearMerge() { mergeTarget = -1 }
    function cancel() { cancelDock(); cancelFolder() }
}
