import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons
import ".."

// App icons can be theme images or the same font glyph used by a shell widget.
Item {
    id: root
    property string glyph: ""
    property url source: ""
    property url fallbackSource: ""
    property color color: Commons.Color.foreground
    property string fontFamily: Style.font.family

    Image {
        id: image
        objectName: "app-icon-image"
        anchors.fill: parent
        visible: root.glyph === "" && status !== Image.Error
        source: root.glyph === "" ? root.source : ""
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Math.max(128, width * 4 * Screen.devicePixelRatio), Math.max(128, height * 4 * Screen.devicePixelRatio))
        mipmap: true
        smooth: true
        antialiasing: true
    }
    Image {
        anchors.fill: parent
        visible: root.glyph === "" && image.status === Image.Error
        source: visible ? root.fallbackSource : ""
        fillMode: Image.PreserveAspectFit
        sourceSize: image.sourceSize
        smooth: true
        antialiasing: true
    }
    DockGlyph {
        objectName: "app-icon-glyph"
        anchors.fill: parent
        visible: root.glyph !== ""
        text: root.glyph
        fontFamily: root.fontFamily
        fontSize: Math.min(root.width, root.height)
        color: root.color
    }
}
