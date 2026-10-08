import QtQuick
import QtTest
import "../components"
TestCase {
    name: "TaskbarController"
    Component { id: factory; TaskbarController {} }
    function test_scopedCommandsAndFailurePreserveLastKnownMode() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "taskbarAdapter")
        compare(adapter.starts, 0)
        verify(!item.run("enable;bad"))
        verify(item.run("enable"))
        compare(adapter.command.slice(1), ["taskbar", "enable"])
        verify(!item.run("reset"))
        adapter.complete('{"state":"ok","mode":"enable"}', 0)
        compare(item.mode, "enable")
        verify(item.run("reset"))
        adapter.complete('{"state":"failed","message":"Config changed"}', 1)
        compare(item.mode, "enable")
        compare(item.message, "Config changed")
        verify(item.run("reset"))
        adapter.complete('{"state":"ok","mode":"reset"}', 0)
        compare(item.mode, "reset")
        verify(item.run("status"))
        adapter.complete('not JSON', 0)
        compare(item.mode, "reset")
        verify(item.message.length > 0)
    }
}
