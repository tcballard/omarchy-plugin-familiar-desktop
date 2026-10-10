import QtQuick
Item {
    property var command: []
    property bool stdinEnabled: false
    signal started()
    property var writes: []
    function write(data) { writes = writes.concat([data]) }
    property bool running: false
    property var stderr
    property var stdout
    property int starts: 0
    onRunningChanged: if (running) starts += 1
    signal exited(int exitCode, int exitStatus)
    function complete(text, code) {
        stdout.text = text
        running = false
        if (stdout && typeof stdout.streamFinished === "function") stdout.streamFinished()
        exited(code, 0)
    }
}
