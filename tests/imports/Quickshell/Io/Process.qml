import QtQuick
Item {
    property var command: []
    property bool running: false
    property var stdout
    property int starts: 0
    onRunningChanged: if (running) starts += 1
    signal exited(int exitCode, int exitStatus)
    function complete(text, code) {
        stdout.text = text
        running = false
        exited(code, 0)
    }
}
