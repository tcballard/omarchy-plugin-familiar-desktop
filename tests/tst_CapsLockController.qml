import QtQuick
import QtTest
import "../components"

TestCase {
    name: "CapsLockController"
    Component { id: factory; CapsLockController {} }
    function test_explicitChoiceAndSerializedCommands() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "capsLockAdapter")
        compare(adapter.starts, 0)
        verify(!item.run("normal; touch /tmp/no"))
        compare(adapter.starts, 0)
        verify(item.run("status"))
        compare(adapter.command.slice(1), ["caps-lock", "status"])
        adapter.complete('{"state":"ok","mode":"reset"}', 0)
        compare(item.mode, "reset")
        verify(item.run("normal"))
        verify(!item.run("compose"))
        compare(item.mode, "reset") // no optimistic success before the backend responds
        compare(adapter.command.slice(1), ["caps-lock", "normal"])
        adapter.complete('{"state":"ok","mode":"normal","message":"Applied"}', 0)
        compare(item.mode, "normal")
    }
    function test_failureMalformedOutputAndRetry() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "capsLockAdapter")
        item.run("compose")
        adapter.complete('{"state":"failed","message":"Reload failed; restored"}', 1)
        compare(item.mode, "")
        verify(item.message.indexOf("Reload failed") >= 0)
        verify(item.run("status"))
        adapter.complete('not json', 0)
        compare(item.mode, "")
        verify(item.run("reset"))
        adapter.complete('{"state":"ok","mode":"reset"}', 0)
        compare(item.mode, "reset")
    }
    function test_unknownModeIsNotSuccess() {
        var item = createTemporaryObject(factory, this)
        var adapter = findChild(item, "capsLockAdapter")
        item.run("status")
        adapter.complete('{"state":"ok","mode":"unknown"}', 0)
        compare(item.mode, "")
        verify(item.message.length > 0)
    }
}
