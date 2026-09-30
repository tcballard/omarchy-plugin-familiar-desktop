import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool enabled: false
    property string style: "mac"
    property string mode: "theme"
    property string fontFamily: "Sans"
    property int fontSize: 13
    property string exclusions: ""
    property color background: "#202020"
    property color foreground: "#ffffff"
    property string state: "checking"
    property string message: "Checking window controls…"
    readonly property bool busy: adapter.running
    readonly property string helper: Qt.resolvedUrl("../scripts/familiar-titlebars.py").toString().replace(/^file:\/\//, "")
    readonly property string ownerToken: String(Date.now()) + "-" + String(Math.random()).slice(2)
    property int revision: 0
    property int requestedRevision: 0
    property bool disposed: false

    function hexColour(value) {
        return "#" + [value.r, value.g, value.b].map(function(channel) {
            return Math.round(channel * 255).toString(16).padStart(2, "0")
        }).join("")
    }

    function schedule() {
        revision += 1
        reconcileTimer.restart()
    }
    function refresh() { schedule() }
    function reconcile() {
        if (disposed || adapter.running) return
        requestedRevision = revision
        adapter.command = ["python3", helper, enabled ? "apply" : "disable", "--owner", ownerToken,
                           "--style", style, "--background", hexColour(background),
                           "--foreground", hexColour(foreground), "--exclude", exclusions,
                           "--mode", mode, "--font-family", fontFamily, "--font-size", String(fontSize)]
        adapter.running = true
    }
    onEnabledChanged: schedule()
    onStyleChanged: schedule()
    onModeChanged: schedule()
    onFontFamilyChanged: schedule()
    onFontSizeChanged: schedule()
    onExclusionsChanged: schedule()
    onBackgroundChanged: schedule()
    onForegroundChanged: schedule()
    Component.onCompleted: schedule()
    FileView {
        id: themeOptions
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/familiar-desktop.json"
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: root.schedule()
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: root.schedule()
    }
    Component.onDestruction: {
        disposed = true
        // A session token prevents an old instance's teardown undoing a newer
        // instance after hot reload. The adapter serializes writes with flock.
        Quickshell.execDetached(["python3", helper, "disable", "--owner", ownerToken, "--if-owner"])
    }
    Timer {
        id: reconcileTimer
        objectName: "titlebarReconcileTimer"
        interval: 200
        onTriggered: root.reconcile()
    }
    Process {
        id: adapter
        objectName: "titlebarAdapter"
        stdout: StdioCollector { id: resultCollector; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            watchdog.stop()
            if (root.disposed) return
            if (root.requestedRevision !== root.revision) {
                reconcileTimer.restart()
                return
            }
            try {
                var result = JSON.parse(resultCollector.text)
                root.state = exitCode === 0 ? (result.state || "failed") : "failed"
                root.message = String(result.message || "Window-control update failed.").slice(0, 300)
            } catch (error) {
                root.state = "failed"
                root.message = "Window-control helper failed. Check that python3 and hyprctl are installed."
            }
        }
        onRunningChanged: if (running) watchdog.restart()
    }
    Timer {
        id: watchdog
        objectName: "titlebarWatchdog"
        interval: 30000
        onTriggered: {
            adapter.running = false
            root.state = "failed"
            root.message = "Window-control update timed out. Retry when Hyprland is responding."
        }
    }
}
