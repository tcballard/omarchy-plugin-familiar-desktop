import QtQml
QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true
    property bool preload: true
    property bool atomicWrites: false
    property string contents: ""
    signal loaded()
    function text() { return contents }
    function setText(value) { contents = value }
    function reload() { loaded() }
    signal fileChanged()
}
