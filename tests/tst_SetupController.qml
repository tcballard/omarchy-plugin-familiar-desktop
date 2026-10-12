import QtQuick
import QtTest
import "../components"

TestCase {
    name: "SetupController"
    Component { id: controller; SetupController {} }
    function make() { return createTemporaryObject(controller, this) }
    function proc(item) { return findChild(item, "setupProcess") }
    function test_freshInstallIsExplicitAndSerialized() {
        var item = make(), adapter = proc(item)
        compare(adapter.command[2], "status")
        adapter.complete("Setup required", 3)
        compare(item.state, "needed")
        verify(item.opened)
        compare(adapter.starts, 1)
        item.style = "mac"
        verify(item.start())
        compare(adapter.command, ["timeout", "--kill-after=5", "600", "bash", item.script, "install", "mac"])
        verify(!item.start())
        adapter.stdout.text = "Checking…\nDownloading backend…\n"
        compare(item.message, "Downloading backend…")
        adapter.complete("Familiar is ready.", 0)
        verify(item.ready)
        verify(!item.busy)
    }
    function test_existingInstallDoesNotOpenSetup() {
        var item = make()
        proc(item).complete("ready", 0)
        verify(item.ready)
        verify(!item.opened)
    }
    function test_officialHostExplainsCoreOwnershipBeforeInstall() {
        var item = make()
        proc(item).complete("Omarchy manages window controls.\nSetup required", 3)
        compare(item.officialTitlebars, true)
        compare(item.ready, false)
        item.start()
        proc(item).complete("Familiar is ready.", 0)
        compare(item.officialTitlebars, true)
        compare(item.ready, true)
        item.check()
        proc(item).complete("Familiar is ready.", 0)
        compare(item.officialTitlebars, false)
    }
    function test_failureRetryAndBoundedDetails() {
        var item = make(), adapter = proc(item)
        adapter.complete("needed", 3)
        item.start()
        adapter.complete("x".repeat(8000), 1)
        compare(item.state, "failed")
        verify(item.details.length <= 3000)
        verify(!item.ready)
        verify(item.start())
        adapter.complete("ready", 0)
        verify(item.ready)
    }
    function test_reloadWaitsForExistingInstaller() {
        var item = make()
        proc(item).complete("already running", 4)
        compare(item.state, "waiting")
        verify(item.busy)
        verify(!item.start())
        item.check()
        proc(item).complete("ready", 0)
        verify(item.ready)
    }
    function test_disabledCompletionCannotActivate() {
        var item = make(), adapter = proc(item)
        adapter.complete("needed", 3)
        item.start()
        item.active = false
        adapter.complete("ready", 0)
        verify(!item.ready)
        verify(!item.opened)
        item.active = true
        compare(adapter.command[2], "status")
        adapter.complete("ready", 0)
        verify(item.ready)
    }
    function test_watchdogDoesNotAcceptLateSuccess() {
        var item = make(), adapter = proc(item)
        adapter.complete("needed", 3)
        item.start()
        findChild(item,"setupWatchdog").triggered()
        adapter.complete("late success", 0)
        compare(item.state, "failed")
    }
}
