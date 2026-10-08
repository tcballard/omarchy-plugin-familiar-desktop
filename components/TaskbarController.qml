import QtQuick
import Quickshell.Io

Item {
    id: root
    property string helper: Qt.resolvedUrl("../bin/familiar-desktop").toString().replace(/^file:\/\//, "")
    readonly property bool busy: adapter.running
    property string mode: "reset"
    property string message: ""
    property string operation: ""
    signal completed(string operation)
    function run(choice) {
        if (busy || ["enable", "reset", "status"].indexOf(choice) < 0) return false
        operation = choice
        message = ""
        adapter.command = [helper, "taskbar", choice]
        adapter.running = true
        return true
    }
    Process {
        id: adapter
        objectName: "taskbarAdapter"
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: function(code, status) {
            try {
                var result = JSON.parse(output.text)
                if (code !== 0 || result.state !== "ok" || ["enable", "reset"].indexOf(result.mode) < 0) {
                    root.message = String(result.message || "Could not change taskbar layout.").slice(0, 300)
                    return
                }
                root.mode = result.mode
                root.message = String(result.message || "").slice(0, 300)
                root.completed(root.operation)
            } catch (e) {
                root.message = "Could not read taskbar state. Check the installed Familiar backend."
            }
        }
    }
}
