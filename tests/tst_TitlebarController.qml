import QtQuick
import QtTest
import Quickshell
import "../components"

TestCase {
    name: "TitlebarController"
    Component { id: controller; TitlebarController {} }

    function makeController() {
        var item = createTemporaryObject(controller, this, { enabled: true })
        verify(item !== null)
        return item
    }
    function adapterFor(item) { return findChild(item, "titlebarAdapter") }

    function test_refreshIsSerializedAndStaleCompletionIsIgnored() {
        var item = makeController()
        var adapter = adapterFor(item)
        tryCompare(adapter, "running", true)
        compare(adapter.command[0], item.helper)
        compare(adapter.command[1], "titlebars")
        compare(adapter.starts, 1)
        verify(adapter.command.indexOf("--include-browsers") < 0)
        item.skipBrowserTitlebars = false
        item.mode = "windows"
        item.refresh()
        wait(220)
        compare(adapter.starts, 1)
        adapter.complete('{"state":"active","message":"obsolete"}', 0)
        verify(item.message !== "obsolete")
        tryCompare(adapter, "starts", 2)
        compare(adapter.command[adapter.command.indexOf("--mode") + 1], "windows")
        verify(adapter.command.indexOf("--include-browsers") >= 0)
        adapter.complete('{"state":"active","message":"current"}', 0)
        compare(item.state, "active")
        compare(item.message, "current")
    }
    function test_disableQueuesBehindApplyAndUsesSameOwner() {
        var item = makeController()
        var adapter = adapterFor(item)
        tryCompare(adapter, "running", true)
        var owner = item.ownerToken
        item.enabled = false
        adapter.complete('{"state":"active"}', 0)
        tryCompare(adapter, "starts", 2)
        compare(adapter.command[2], "disable")
        compare(adapter.command[adapter.command.indexOf("--owner") + 1], owner)
        adapter.complete('{"state":"off"}', 0)
        compare(item.state, "off")
    }
    function test_failureMalformedResponseAndRecovery() {
        var item = makeController()
        var adapter = adapterFor(item)
        tryCompare(adapter, "running", true)
        adapter.complete("invalid JSON", 1)
        compare(item.state, "failed")
        item.refresh()
        tryCompare(adapter, "starts", 2)
        adapter.complete('{"state":"failed","message":"'+ "x".repeat(1000) +'"}', 1)
        compare(item.message.length, 300)
        item.refresh()
        tryCompare(adapter, "starts", 3)
        adapter.complete('{"state":"active","message":"ready"}', 0)
        compare(item.state, "active")
    }
    function test_watchdogStopsOperation() {
        var item = makeController()
        var adapter = adapterFor(item)
        tryCompare(adapter, "running", true)
        findChild(item, "titlebarWatchdog").triggered()
        compare(adapter.running, false)
        compare(item.state, "failed")
        verify(item.message.indexOf("timed out") >= 0)
    }
    function test_palette_change_reapplies_colours() {
        var item = makeController()
        var adapter = adapterFor(item)
        tryCompare(adapter, "running", true)
        adapter.complete('{"state":"active"}', 0)
        item.background = "#f0f2f4"
        item.foreground = "#202830"
        tryCompare(adapter, "starts", 2)
        compare(adapter.command[adapter.command.indexOf("--background") + 1], "#f0f2f4")
        compare(adapter.command[adapter.command.indexOf("--foreground") + 1], "#202830")
        adapter.complete('{"state":"active"}', 0)
    }
    function test_teardownUsesConditionalOwnership() {
        Quickshell.detachedCommands = []
        var item = controller.createObject(this)
        var owner = item.ownerToken
        item.destroy()
        tryVerify(function() { return Quickshell.detachedCommands.length === 1 })
        var argv = Quickshell.detachedCommands[0]
        compare(argv[2], "disable")
        compare(argv[argv.indexOf("--owner") + 1], owner)
        verify(argv.indexOf("--if-owner") >= 0)
    }
}
