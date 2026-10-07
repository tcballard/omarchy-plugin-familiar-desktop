import QtQuick
import QtTest
import "../components"
import "../ShortcutCoach.js" as Coach

TestCase {
    name: "ShortcutCoach"
    visible: true
    width: 800
    height: 620
    when: windowShown
    Component { id: storeFactory; ShortcutCoachStore {} }
    Component { id: controllerFactory; ShortcutCoachController { available: false } }
    Component { id: cardFactory; ShortcutCoachCard { width: 360 } }
    Component { id: progressFactory; ShortcutCoachProgress { width: 450 } }
    Component {
        id: settingsFactory
        SettingsFrame {
            id: frame
            property var coach: null
            width: 800
            height: 560
            contentHeight: content.implicitHeight
            ShortcutCoachProgress { id: content; width: parent.width; controller: frame.coach }
        }
    }
    property var store
    property var controller
    property var bindings: [
        {description: "Full width", key: "F", keys: "Super + Alt + F", dispatcher: "__lua"},
        {description: "Close window", key: "Q", keys: "Super + Q", dispatcher: "__lua"},
        {description: "Toggle window floating/tiling", key: "T", keys: "Super + T", dispatcher: "__lua"}
    ]
    function init() {
        store = createTemporaryObject(storeFactory, this)
        store.load("")
        controller = createTemporaryObject(controllerFactory, this, {store: store})
        controller.available = true
        var reader = findChild(controller, "shortcutCoachBindings")
        reader.complete(JSON.stringify({state: "ok", coachBindings: bindings}), 0)
    }
    function test_dismiss_learn_progress_and_restart() {
        var card = createTemporaryObject(cardFactory, this, {controller: controller})
        var progress = createTemporaryObject(progressFactory, this, {controller: controller})
        verify(controller.trigger("maximizeWindow"))
        verify(!controller.trigger("closeWindow"))
        verify(!controller.trigger("maximizeWindow"))
        wait(20)
        mouseClick(findChild(card, "coach-remind-later"))
        compare(controller.activeLesson, null)
        verify(!controller.learningState.lessons.maximizeWindow.learned)
        verify(!controller.trigger("maximizeWindow"))
        controller.reset()
        verify(controller.trigger("closeWindow"))
        mouseClick(findChild(card, "coach-got-it"))
        compare(controller.progress.learned, 1)
        compare(progress.progress.learned, 1)
        compare(controller.activeLesson, null)
        verify(!controller.trigger("closeWindow"))
        var disk = findChild(store, "shortcutCoachFile").savedBuffer
        var restarted = createTemporaryObject(storeFactory, this)
        restarted.load(disk)
        var next = createTemporaryObject(controllerFactory, this, {store: restarted})
        next.available = true
        next.setBindings(bindings)
        compare(next.progress.learned, 1)
        verify(!next.trigger("closeWindow"))
        next.setEnabled(false)
        verify(!next.trigger("toggleFloating"))
        next.setEnabled(true)
        compare(next.progress.learned, 1)
        verify(!next.trigger("closeWindow"))
    }
    function test_reset_requires_confirmation_preserves_toggle() {
        controller.markLearned("closeWindow")
        controller.setEnabled(false)
        var progress = createTemporaryObject(progressFactory, this, {controller: controller})
        wait(20)
        mouseClick(findChild(progress, "coach-reset"))
        compare(controller.progress.learned, 1)
        mouseClick(findChild(progress, "coach-reset-cancel"))
        compare(controller.progress.learned, 1)
        mouseClick(findChild(progress, "coach-reset"))
        mouseClick(findChild(progress, "coach-reset-confirm"))
        compare(controller.progress.learned, 0)
        compare(Object.keys(controller.learningState.lessons).length, 0)
        compare(controller.learningState.lastHintAt, 0)
        compare(controller.hintsEnabled, false)
        controller.setEnabled(true)
        verify(controller.trigger("closeWindow"))
        mouseClick(findChild(progress, "coach-enabled"))
        compare(controller.hintsEnabled, false)
        compare(controller.activeLesson, null)
    }
    function test_automatic_timeout_and_failures() {
        controller.hintDuration = 20
        verify(controller.trigger("maximizeWindow"))
        tryCompare(controller, "activeLesson", null)
        compare(controller.learningState.lessons.maximizeWindow.hintsShown, 1)
        verify(!controller.trigger("unknown"))
        controller.reset()
        var previousDisk = findChild(store, "shortcutCoachFile").savedBuffer
        findChild(store, "shortcutCoachFile").failWrites = true
        verify(controller.trigger("closeWindow"))
        verify(store.message.length > 0)
        compare(findChild(store, "shortcutCoachFile").savedBuffer, previousDisk)
        controller.dismiss()
        var broken = {learningState: Coach.normalize({}), ready: true, writable: true,
            update: function() { throw new Error("fixture persistence failure") }}
        controller.store = broken
        verify(!controller.trigger("closeWindow"))
        compare(controller.activeLesson, null)
        controller.actionCompleted({state: "ok", action: "arrange-maximize"})
        controller.actionCompleted({state: "failed", action: "arrange-maximize"})
    }
    function test_pending_atomic_writes_keep_latest_state() {
        var file = findChild(store, "shortcutCoachFile")
        file.deferWrites = true
        verify(controller.trigger("closeWindow"))
        compare(file.writes, 1)
        controller.markLearned("closeWindow")
        controller.setEnabled(false)
        compare(file.writes, 1)
        file.completeWrite()
        compare(file.writes, 2)
        file.completeWrite()
        var saved = Coach.parse(file.savedBuffer).state
        compare(saved.enabled, false)
        compare(saved.lessons.closeWindow.learned, true)
        compare(store.saving, false)
    }
    function test_missing_corrupt_future_and_unknown_lessons() {
        store.load("{broken")
        compare(controller.progress.learned, 0)
        verify(controller.trigger("closeWindow"))
        store.load('{"schemaVersion":99}')
        compare(controller.ready, false)
        verify(!controller.trigger("closeWindow"))
        store.load('{"lessons":{"futureLesson":{"learned":true},"closeWindow":{"learned":true}}}')
        compare(controller.progress.learned, 1)
        controller.setEnabled(false)
        compare(store.learningState.lessons.futureLesson.learned, true)
        controller.reset()
        compare(Object.keys(store.learningState.lessons).length, 0)
    }
    function test_binding_refresh_drops_stale_results() {
        controller.refreshBindings()
        compare(controller.lessons.length, 0)
        var reader = findChild(controller, "shortcutCoachBindings")
        compare(reader.command.slice(-2), ["desktop", "shortcuts"])
        controller.refreshBindings()
        reader.complete(JSON.stringify({state: "ok", coachBindings: bindings}), 0)
        compare(controller.lessons.length, 0)
        verify(reader.running)
        reader.complete(JSON.stringify({state: "ok", coachBindings: bindings.slice(1)}), 0)
        compare(controller.lessons.length, 2)
        controller.refreshBindings()
        reader.complete("not JSON", 1)
        compare(controller.lessons.length, 0)
        controller.refreshBindings()
        controller.available = false
        reader.complete(JSON.stringify({state: "ok", coachBindings: bindings}), 0)
        compare(controller.lessons.length, 0)
        verify(!controller.trigger("closeWindow"))
    }
    function test_mac_labels_and_rendered_layout() {
        controller.labelStyle = "mac"
        verify(controller.trigger("maximizeWindow"))
        var card = createTemporaryObject(cardFactory, this, {controller: controller})
        card.height = card.implicitHeight
        wait(20)
        compare(findChild(card, "coach-shortcut").text, "Next time: Command + Option + F")
        verify(card.height < 280)
        grabImage(card).save("/tmp/familiar-shortcut-coach-toast.png")
        card.visible = false
        controller.markLearned("closeWindow")
        var progress = createTemporaryObject(progressFactory, this, {controller: controller})
        wait(20)
        verify(progress.implicitHeight < 400)
        grabImage(progress).save("/tmp/familiar-shortcut-coach-progress.png")
        compare(progress.progress.learned, 1)
        compare(progress.progress.total, 3)
    }
    function test_populated_settings_at_supported_widths() {
        controller.markLearned("closeWindow")
        var frame = createTemporaryObject(settingsFactory, this, {coach: controller})
        frame.page = "keyboard"
        frame.section = "coach"
        for (var width of [800, 560]) {
            frame.width = width
            wait(20)
            var scroll = findChild(frame, "settings-scroll")
            verify(frame.contentHeight <= scroll.height + 1)
            if (width === 800) grabImage(frame).save("/tmp/familiar-shortcut-coach-settings.png")
        }
    }
}
