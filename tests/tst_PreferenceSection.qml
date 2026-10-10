import QtQuick
import QtTest
import "../components"

TestCase {
    id: test
    name: "PreferenceSection"
    width: 560; height: 560
    visible: true
    when: windowShown
    QtObject {
        id: controller
        property string mode: "reset"
        property bool busy: false
        property string message: "Use configuration"
        property var requests: []
        function run(mode) { requests = requests.concat([mode]) }
    }
    Component { id: caps; CapsLockSettings {} }
    Component { id: gestures; GesturesSettings {} }
    Component { id: windows; WindowModeSettings {} }
    function init() { controller.requests = []; controller.mode = "reset"; controller.busy = false }
    function test_choices_data() {
        return [
            {tag: "caps", component: caps, choice: "compose", title: "Caps Lock behaviour"},
            {tag: "gestures", component: gestures, choice: "workspace", title: "Trackpad gestures"},
            {tag: "windows", component: windows, choice: "floating", title: "Desktop mode"}
        ]
    }
    function test_choices(data) {
        var panel = createTemporaryObject(data.component, test, {controller: controller, width: 500})
        verify(panel !== null)
        compare(panel.title, data.title)
        compare(controller.requests.length, 0, "rendering never applies a preference")
        var choice = findChild(panel, "choice-" + data.choice)
        verify(choice !== null)
        mouseClick(choice)
        compare(controller.requests, [data.choice])
        compare(choice.selected, false, "the controller owns selection")
        controller.mode = data.choice
        compare(choice.selected, true)
        choice.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(controller.requests, [data.choice, data.choice])
        mouseClick(findChild(panel, "preference-refresh"))
        compare(controller.requests, [data.choice, data.choice, "status"])
        controller.busy = true
        compare(choice.enabled, false)
        compare(findChild(panel, "preference-refresh").enabled, false)
        compare(findChild(panel, "preference-status").text, "Applying…")
        mouseClick(choice)
        compare(controller.requests.length, 3)
        panel.controller = null
        compare(choice.enabled, false)
        compare(findChild(panel, "preference-status").text, "Familiar service is unavailable.")
    }
}
