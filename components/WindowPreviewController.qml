import QtQuick

Item {
    id: root
    property bool allowed: true
    property var target: null
    property bool iconHovered: false
    property bool popupHovered: false
    property bool opened: false
    property int openDelay: 350
    property int closeDelay: 220
    readonly property var app: target ? target.itemData : null
    readonly property bool eligible: allowed && !!target && target.visible && !!app
        && !app.isStack && app.isRunning && !!app.toplevels && app.toplevels.length > 0
    onEligibleChanged: if (!eligible) {
        opened = false
        enterTimer.stop()
        // Clear the source after the eligibility binding finishes evaluating.
        Qt.callLater(function() { if (!root.eligible) root.close() })
    }
    onPopupHoveredChanged: {
        if (popupHovered) leaveTimer.stop()
        else if (!iconHovered) leaveTimer.restart()
    }
    function enter(item) {
        if (target !== item) close()
        target = item
        iconHovered = true
        leaveTimer.stop()
        if (eligible && !opened) enterTimer.restart()
    }
    function leave(item) {
        if (target !== item) return
        iconHovered = false
        enterTimer.stop()
        if (!popupHovered) leaveTimer.restart()
    }
    function close() {
        enterTimer.stop()
        leaveTimer.stop()
        opened = false
        target = null
        iconHovered = false
        popupHovered = false
    }
    Timer {
        id: enterTimer
        interval: root.openDelay
        onTriggered: if (root.eligible && root.iconHovered) root.opened = true
    }
    Timer {
        id: leaveTimer
        interval: root.closeDelay
        onTriggered: if (!root.iconHovered && !root.popupHovered) root.close()
    }
}
