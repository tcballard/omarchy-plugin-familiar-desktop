import QtQml
QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true
    property bool preload: true
    property bool atomicWrites: true
    property string buffer: ""
    property string savedBuffer: ""
    property bool failWrites: false
    property bool deferWrites: false
    property int writes: 0
    signal loaded()
    signal loadFailed(int error)
    signal saved()
    signal saveFailed(int error)
    signal fileChanged()
    function text() { return buffer }
    function reload() { loaded() }
    function setText(value) {
        buffer = value
        writes++
        if (!deferWrites) completeWrite()
    }
    function completeWrite() {
        if (failWrites) saveFailed(1)
        else { savedBuffer = buffer; saved() }
    }
}
