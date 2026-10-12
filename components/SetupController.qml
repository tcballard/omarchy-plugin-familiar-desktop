import QtQuick
import Quickshell.Io

// One service owns setup across every monitor and bar instance.
Item {
    id: root
    property bool active: true
    property bool canStart: true
    property string state: "checking"
    property string message: "Checking Familiar…"
    property string details: ""
    property bool opened: false
    property string style: "windows"
    property bool applyLayout: true
    property string operation: "status"
    property bool timedOut: false
    property bool officialTitlebars: false
    readonly property bool ready: state === "ready"
    readonly property bool busy: adapter.running || state === "waiting"
    readonly property string script: Qt.resolvedUrl("../setup-in-app.sh").toString().replace(/^file:\/\//, "")
    signal installed(string style)

    function check() {
        if (!active || adapter.running) return
        operation = "status"
        timedOut = false
        adapter.command = ["bash", script, "status"]
        adapter.running = true
    }
    function show() { opened = true }
    function repair(selectedStyle) {
        if (busy) { show(); return }
        applyLayout = false
        style = selectedStyle === "mac" ? "mac" : "windows"
        state = "needed"
        message = "Set up or repair your window controls."
        details = ""
        show()
    }
    function start() {
        if (!active || busy || !canStart) return false
        operation = "install"
        state = "installing"
        message = "Preparing Familiar…"
        details = ""
        timedOut = false
        opened = true
        adapter.command = ["timeout", "--kill-after=5", "600", "bash", script, "install", style]
        adapter.running = true
        return true
    }
    function consume(text) {
        if (operation !== "install" || state !== "installing") return
        var lines = String(text).trim().split("\n")
        message = lines[lines.length - 1].slice(0, 240)
    }
    function complete(code, output) {
        watchdog.stop()
        if (!active) return
        if (operation === "status") officialTitlebars = String(output).indexOf("Omarchy manages window controls.") >= 0
        details = String(output).slice(-3000)
        if (timedOut || code === 124 || code === 137) {
            state = "failed"
            message = "Setup timed out. Check your connection and retry."
            opened = true
        } else if (code === 4) {
            state = "waiting"
            message = "Setup is already running. Waiting for it to finish…"
            opened = true
            retryCheck.restart()
        } else if (code === 0) {
            state = "ready"
            message = "Your desktop is ready."
            if (operation === "install") installed(style)
        } else {
            state = operation === "status" && code === 3 ? "needed" : "failed"
            message = state === "needed" ? "One quick setup, then make yourself at home." : "Setup couldn’t finish. Check the details and try again."
            opened = true
        }
    }
    onActiveChanged: {
        if (active) check()
        else { opened = false; retryCheck.stop(); adapter.running = false }
    }
    Component.onCompleted: check()
    Process {
        id: adapter
        objectName: "setupProcess"
        stdout: StdioCollector {
            id: output
            waitForEnd: false
            onTextChanged: root.consume(text)
        }
        stderr: StdioCollector { id: errors; waitForEnd: true }
        onRunningChanged: if (running) watchdog.restart()
        onExited: function(code, status) { root.complete(status === 0 ? code : 1, output.text + "\n" + errors.text) }
    }
    Timer {
        id: retryCheck
        interval: 2000
        onTriggered: root.check()
    }
    Timer {
        id: watchdog
        objectName: "setupWatchdog"
        interval: root.operation === "status" ? 15000 : 620000
        onTriggered: {
            root.timedOut = true
            adapter.running = false
            root.complete(124, "Setup exceeded its time limit.")
        }
    }
}
