import QtQuick
import QtTest
import "../components"
TestCase {
    name: "SettingsStore"
    SettingsStore { id: store; path: "/fictional/settings.json" }
    function test_roundTripAndFailures() {
        verify(store.restore('{"showFolderTitles":false,"widgetsEnabled":false,"dockWidgets":[],"skipBrowserTitlebars":false}'))
        compare(store.showFolderTitles, false)
        compare(store.dockWidgets.length, 0)
        verify(store.patch({dockSize: "large"}))
        compare(store.dockSize, "large")
        compare(store.skipBrowserTitlebars, false)
        compare(store.showFolderTitles, false)
        verify(!store.patch({unknownPreference: true}))
        verify(!store.restore('broken JSON'))
        compare(store.dockSize, "large")
        verify(store.error !== "")
        verify(store.restore('{"dockPosition":"right"}'))
        compare(store.dockPosition, "right")
    }
    function test_externalEditsUnknownFieldsAndFailedSave() {
        var file = findChild(store, "settings-file")
        file.contents = '{"futurePreference":{"keep":42},"showFolderTitles":false,"dockWidgets":[]}'
        file.reload()
        compare(store.showFolderTitles, false)
        verify(store.patch({dockSize: "extra-large"}))
        var saved = JSON.parse(file.contents)
        compare(saved.futurePreference.keep, 42)
        compare(saved.showFolderTitles, false)
        compare(saved.dockWidgets.length, 0)
        var position = store.dockPosition
        file.contents = 'broken external JSON'
        verify(!store.patch({dockPosition: "right"}))
        compare(file.contents, 'broken external JSON')
        compare(store.dockPosition, position)
        verify(store.error !== "")
        file.contents = '{"dockPosition":"left"}'
        store.reload()
        compare(store.dockPosition, "left")
        compare(store.error, "")
    }

}
