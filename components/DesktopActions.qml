import QtQuick
import Quickshell.Io

// One service instance owns operations for all bar/dock surfaces.
Item {
    id: root
    property string helper: Qt.resolvedUrl("../bin/familiar-desktop").toString().replace(/^file:\/\//, "")
    readonly property bool busy: adapter.running
    property string message: ""
    property var shortcuts: []
    property var tools: []
    signal completed(string operation)
    property string operation: ""
    function run(args) {
        if (busy || !args.length) return false
        operation = args[0]
        message = ""
        adapter.command = [helper, "desktop"].concat(args)
        adapter.running = true
        return true
    }
    Process {
        id: adapter
        objectName: "desktopAdapter"
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: function(code, status) {
            try {
                var result = JSON.parse(output.text)
                if (code !== 0 || result.state !== "ok") {
                    root.message = String(result.message || "Action failed.").slice(0, 300)
                    return
                }
                if (root.operation === "shortcuts") { root.shortcuts = result.shortcuts || []; root.tools = result.tools || [] }
                root.message = String(result.message || "").slice(0, 300)
                root.completed(root.operation)
            } catch (e) {
                root.message = "Familiar could not complete the action. Check the installed backend."
            }
        }
    }
}
