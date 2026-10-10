import QtQuick
import QtTest
import Quickshell.Wayland
import "../components"

TestCase {
    name: "NotificationTracker"
    Component { id: factory; NotificationTracker {} }
    function createTracker() {
        var item = createTemporaryObject(factory, this)
        wait(0) // finish the component's initial hydration
        return item
    }
    function cleanup() { ToplevelManager.activeToplevel = null }
    function test_titlesEventsFocusAndClosure() {
        var t = createTracker()
        var browser = {appId: "chromium", title: "(3) Inbox"}
        var webapp = {appId: "chrome-web.whatsapp.com__-Default", title: "(4) Chat"}
        t.knownWindows = [browser, webapp]
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, 3)
        compare(t.canonicalCounts.whatsapp, 4)
        browser.title = "(1) Inbox"
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, 1)
        browser.title = "Inbox"
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, undefined)
        compare(t.canonicalCounts.whatsapp, 4)
        browser.title = "(3) Inbox"
        t.syncWindowTitles()
        t.incrementBadge("chromium", 1, true)
        compare(t.notificationCounts.chrome, 1)
        compare(t.canonicalCounts.chrome, 3) // combine sources by maximum
        browser.title = "Inbox"
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, 1)
        compare(t.canonicalUrgent.chrome, true)
        t.clearByRawIdentifier("chrome")
        compare(t.canonicalCounts.chromium, undefined)
        compare(t.canonicalUrgent.chrome, undefined)
        browser.title = "(3) Inbox"
        var second = {appId: "chromium", title: "[5] Other inbox"}
        t.knownWindows = [browser, second, webapp]
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, 5)
        second.title = "[2] Other inbox"
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, 3)
        ToplevelManager.activeToplevel = browser
        t.clearBadge({appId: "chromium"})
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, undefined)
        ToplevelManager.activeToplevel = null
        t.syncWindowTitles()
        compare(t.canonicalCounts.chrome, 3)
        t.knownWindows = []
        t.syncWindowTitles()
        compare(Object.keys(t.canonicalCounts).length, 0)
        compare(Object.keys(t.canonicalUrgent).length, 0)
    }
    function test_emptyPersistenceDoesNotResurrectDiskState() {
        var t = createTracker()
        var file = findChild(t, "badge-state-file")
        file.contents = '{"counts":{"chrome":7},"urgent":{"chrome":true}}'
        t.loadDiskState()
        compare(t.canonicalCounts.chrome, 7)
        t.clearByRawIdentifier("chromium")
        t.loadDiskState()
        compare(Object.keys(t.canonicalCounts).length, 0)
        var saved = findChild(t, "badge-persistence")
        var reloaded = createTracker()
        var restored = findChild(reloaded, "badge-persistence")
        restored.counts = saved.counts
        restored.urgent = saved.urgent
        restored.loaded = saved.loaded
        findChild(reloaded, "badge-state-file").contents = file.contents
        reloaded.loadDiskState()
        compare(Object.keys(reloaded.canonicalCounts).length, 0)
        reloaded.knownWindows = [{appId: "chromium", title: "(9) Inbox"}]
        reloaded.syncWindowTitles()
        compare(reloaded.canonicalCounts.chrome, 9)
        compare(Object.keys(restored.counts).length, 0) // titles are never persisted
    }
    function test_privateTextIsNotIdentityOrAnArgument() {
        var t = createTracker()
        var secret = "Private appointment 8675309"
        t.processIncomingNotification({app: "chromium", summary: secret, urgency: 2})
        compare(t.canonicalCounts.chrome, 1)
        compare(t.canonicalUrgent.chrome, true)
        compare(Object.keys(t.canonicalCounts).length, 2)
        t.processIncomingNotification({summary: secret})
        compare(Object.keys(t.canonicalCounts).length, 2)
        t.processIncomingNotification({app: "org.telegram.desktop", summary: secret})
        compare(t.canonicalCounts.telegram, 1)
        verify(JSON.stringify(t.canonicalCounts).indexOf(secret) < 0)
        var legacy = {}; legacy[secret] = 2
        t.notificationCounts = legacy
        findChild(t, "badge-save-timer").triggered()
        var process = findChild(t, "badge-save")
        compare(process.command.slice(1), ["badges", "save", "--stdin"])
        compare(process.command.length, 4)
        verify(process.stdinEnabled)
        process.started()
        compare(JSON.parse(process.writes[0]).counts[secret], 2)
        verify(!process.stdinEnabled)
        compare(process.payload, "")
    }
    function test_sharedAliases() {
        var t = createTracker()
        t.incrementBadge("transmission-gtk", 1, false)
        compare(t.getBadgeCount("com.transmissionbt.Transmission.desktop", null, "", ""), 1)
        compare(t.toCanonical("https://google.com/photos"), "photos")
        compare(t.toCanonical("yandex-browser"), "yandex-browser")
    }
}
