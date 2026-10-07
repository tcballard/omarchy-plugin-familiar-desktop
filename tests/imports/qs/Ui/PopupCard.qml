import QtQuick
// Portable content/lifetime harness only; does not emulate Wayland placement.
Item {
    required property Item anchorItem
    required property QtObject bar
    property var owner: null
    property string triggerMode: "click"
    property bool centerOnBar: false
    property bool open: false
    property bool containsMouse: false
    property int padding: 10
    property int contentWidth: 600
    property int contentHeight: 200
    width: contentWidth
    height: contentHeight
    visible: open
    function fittedContentWidth(w) { return Math.min(w, 680) }
    function fittedContentHeight(h) { return h + 20 }
}
