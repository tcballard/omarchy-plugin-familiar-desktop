import QtQuick
Item {
    objectName: "test-capture"
    property var captureSource: null
    property bool live: false
    property bool paintCursor: false
    property size constraintSize
    property bool hasContent: captureSource !== null
    implicitWidth: constraintSize.width
    implicitHeight: constraintSize.height
    signal stopped()
}
