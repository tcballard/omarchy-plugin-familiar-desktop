import QtQuick
import Quickshell
import Quickshell.Io
import "../ShortcutCoach.js" as Coach

// The shared service is the sole writer. A separate file avoids competing with
// the dock and bar's existing settings writers; FileView uses atomic renames.
Item {
    id: root
    property string path: Quickshell.env("HOME") + "/.config/omarchy/familiar-desktop-shortcut-coach.json"
    property var learningState: Coach.normalize({})
    property bool ready: false
    property bool writable: true
    property string message: ""
    property bool saving: false
    property bool dirty: false

    function load(text) {
        var result = Coach.parse(text)
        learningState = result.state
        writable = result.writable
        message = result.message
        ready = true
    }
    function update(next) {
        if (!ready || !writable) return false
        learningState = Coach.normalize(next)
        dirty = true
        flush()
        return true
    }
    function flush() {
        if (!dirty || saving) return
        dirty = false
        saving = true
        try { file.setText(JSON.stringify(learningState, null, 2) + "\n") }
        catch (e) { failed() }
    }
    function failed() {
        saving = false
        dirty = false
        message = "Learning progress could not be saved. Check the file permissions."
    }
    FileView {
        id: file
        objectName: "shortcutCoachFile"
        path: root.path
        atomicWrites: true
        printErrors: false
        onLoaded: if (!root.saving && !root.dirty) root.load(text())
        onLoadFailed: root.load("")
        onSaved: {
            root.saving = false
            root.message = ""
            root.flush()
        }
        onSaveFailed: root.failed()
    }
}
