import QtQuick
import Quickshell.Io
import "../ShortcutCoach.js" as Coach

Item {
    id: root
    property var store: null
    property bool available: true
    property string helper: Qt.resolvedUrl("../bin/familiar-desktop").toString().replace(/^file:\/\//, "")
    property var lessons: []
    property var activeLesson: null
    property string labelStyle: "standard"
    property int hintDuration: 12000
    readonly property var learningState: store ? store.learningState : Coach.normalize({enabled: false})
    readonly property var progress: Coach.progress(lessons, learningState)
    readonly property bool ready: !!store && store.ready && store.writable
    readonly property bool hintsEnabled: learningState.enabled
    property bool refreshPending: false

    function trigger(id) {
        // Coaching errors never propagate into a desktop action or IPC caller.
        try {
            if (!available || !ready || activeLesson) return false
            var lesson = lessons.find(function(l) { return l.id === id })
            var now = Date.now()
            if (!Coach.eligible(lesson, learningState, now)) return false
            if (!store.update(Coach.shown(learningState, id, now))) return false
            activeLesson = lesson
            dismissTimer.restart()
            return true
        } catch (e) { return false }
    }
    function actionCompleted(result) {
        try { trigger(Coach.actionLesson(result)) } catch (e) {}
    }
    function dismiss() { dismissTimer.stop(); activeLesson = null }
    function markLearned(id) {
        if (!ready || !Coach.find(id)) return
        try { store.update(Coach.learned(learningState, id)) } catch (e) {}
        if (activeLesson && activeLesson.id === id) dismiss()
    }
    function setEnabled(value) {
        if (!ready) return
        var next = Coach.normalize(learningState)
        next.enabled = value === true
        store.update(next)
    }
    function reset() {
        if (!ready) return
        dismiss()
        store.update(Coach.normalize({enabled: hintsEnabled}))
    }
    function refreshBindings() {
        lessons = []
        dismiss()
        if (!available) return
        if (bindingReader.running) { refreshPending = true; return }
        refreshPending = false
        bindingReader.command = [helper, "desktop", "shortcuts"]
        bindingReader.running = true
    }
    function setBindings(bindings) { lessons = Coach.catalogue(bindings); dismiss() }
    onLearningStateChanged: if (!learningState.enabled || (activeLesson && Coach.lessonState(learningState.lessons[activeLesson.id]).learned)) dismiss()
    onAvailableChanged: {
        if (available) refreshBindings()
        else { lessons = []; dismiss() }
    }
    Component.onCompleted: if (available) refreshBindings()
    Timer { id: dismissTimer; interval: root.hintDuration; onTriggered: root.dismiss() }
    Process {
        id: bindingReader
        objectName: "shortcutCoachBindings"
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: function(code) {
            if (root.refreshPending) { root.refreshBindings(); return }
            try {
                var result = JSON.parse(output.text)
                if (root.available && code === 0 && result.state === "ok") root.setBindings(result.coachBindings)
            } catch (e) { root.lessons = [] }
        }
    }
}
