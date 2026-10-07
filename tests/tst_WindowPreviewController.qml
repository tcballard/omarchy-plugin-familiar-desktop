import QtQuick
import QtTest
import "../components"
import "../WindowPreviews.js" as Previews

TestCase {
    name: "WindowPreviewController"
    when: windowShown
    visible: true
    Item { id: icon; property var itemData: ({isRunning:true, toplevels:[{}]}) }
    Item { id: other; property var itemData: ({isRunning:true, toplevels:[{}]}) }
    WindowPreviewController { id: controller; openDelay: 20; closeDelay: 30 }
    function init() { controller.close(); controller.allowed = true }
    function test_hover_delay_and_popup_bridge() {
        controller.enter(icon)
        compare(controller.opened, false)
        tryCompare(controller, "opened", true)
        controller.leave(icon)
        controller.popupHovered = true
        wait(50)
        compare(controller.opened, true)
        controller.popupHovered = false
        tryCompare(controller, "opened", false)
        tryCompare(controller, "target", null)
    }
    function test_fast_crossing_and_disable_cancel_capture() {
        controller.enter(icon)
        controller.leave(icon)
        wait(50)
        compare(controller.opened, false)
        controller.enter(icon)
        tryCompare(controller, "opened", true)
        controller.enter(other)
        compare(controller.opened, false)
        controller.leave(icon) // A late exit cannot cancel the new target.
        tryCompare(controller, "opened", true)
        compare(controller.target, other)
        controller.allowed = false
        compare(controller.opened, false)
        tryCompare(controller, "target", null)
    }
    function test_empty_app_closes_preview() {
        controller.enter(icon)
        tryCompare(controller, "opened", true)
        icon.itemData = {isRunning:false, toplevels:[]}
        compare(controller.opened, false)
        icon.itemData = {isRunning:true, toplevels:[{}]}
    }
    function test_capture_sources_and_exact_window_identity() {
        var a = {title:"<b>Literal title</b>"}, b = {title:"Second"}
        var hypr = {wayland:a, workspace:{name:"2"}}
        var row = Previews.describe(a, [a,b], [null,hypr])
        compare(row.capture, a)
        compare(row.title, "<b>Literal title</b>")
        compare(row.workspace, "Workspace 2")
        compare(Previews.describe(hypr, [a], [hypr]).capture, a)
        hypr.workspace.name = "special:minimized"
        compare(Previews.describe(a, [a], [hypr]).capture, null)
        compare(Previews.describe(b, [], []).capture, null)
        compare(Previews.currentIndex({toplevels:[b,a]}, a), 1)
        compare(Previews.currentIndex({toplevels:[b]}, a), -1)
    }
}
