import QtQml
QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true
    property bool preload: true
    signal fileChanged()
}
