import QtQuick
import QtTest
import "../components"

TestCase {
    name: "DesktopActions"
    Component { id: factory; DesktopActions {} }
    function test_serializedActionsAndLiteralArguments() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "desktopAdapter")
        verify(item.run(["quit-app", "0xABC"]))
        compare(adapter.command.slice(1), ["desktop", "quit-app", "0xABC"])
        verify(!item.run(["show"]))
        adapter.complete('{"state":"ok","message":"Close requested"}', 0)
        compare(item.message, "Close requested")
        verify(!item.busy)
    }
    function test_failureAndRetry() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "desktopAdapter")
        item.run(["show"])
        adapter.complete('{"state":"failed","message":"Restore windows to recover"}', 1)
        compare(item.message, "Restore windows to recover")
        verify(item.run(["restore"]))
        adapter.complete('{"state":"ok","message":"Restored"}', 0)
        compare(item.message, "Restored")
    }
    function test_activeShortcutsAndCompanions() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "desktopAdapter")
        item.run(["shortcuts"])
        adapter.complete('{"state":"ok","shortcuts":[{"keys":"Super + W","description":"Close"}],"tools":[{"key":"store","available":false}]}',0)
        compare(item.shortcuts.length,1)
        compare(item.tools[0].available,false)
    }
}
