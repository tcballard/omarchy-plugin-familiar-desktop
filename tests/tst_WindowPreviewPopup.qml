import QtQuick
import QtTest
import Quickshell.Wayland
import Quickshell.Hyprland
import "../components"

TestCase {
    name: "WindowPreviewPopup"
    when: windowShown
    width: 700; height: 300
    visible: true
    Item { id: icon; property var itemData: null }
    QtObject { id: bar }
    WindowPreviewController { id: controller; openDelay: 1 }
    WindowPreviewPopup { id: popup; controller: controller; bar: bar }
    QtObject { id: one; property string title: "<b>Literal title</b>"; property string appId: "terminal" }
    QtObject { id: two; property string title: "Second window"; property string appId: "terminal" }
    QtObject { id: three; property string title: "Third window"; property string appId: "terminal" }
    QtObject { id: four; property string title: "Fourth window"; property string appId: "terminal" }
    function test_paging_capture_and_teardown() {
        ToplevelManager.toplevels = {values:[one,two,three,four]}
        icon.itemData = {isRunning:true,toplevels:[one,two,three,four]}
        controller.enter(icon)
        tryCompare(controller, "opened", true)
        compare(popup.pageCount, 2)
        var capture = findChild(popup, "test-capture")
        verify(capture !== null)
        compare(capture.live, true)
        popup.pageIndex = 1
        wait(20)
        capture = findChild(popup, "test-capture")
        compare(capture.captureSource, four)
        capture.stopped()
        tryCompare(capture, "captureSource", null)
        compare(capture.live, false)
        controller.close()
        wait(20)
        compare(findChild(popup, "test-capture"), null)
    }
}
