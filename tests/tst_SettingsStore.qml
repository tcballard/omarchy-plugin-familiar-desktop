import QtQuick
import QtTest
import "../components"
TestCase {
    name: "SettingsStore"
    SettingsStore { id: store; path: "/fictional/settings.json" }
    function test_roundTripAndFailures() {
        verify(store.restore('{"showFolderTitles":false,"widgetsEnabled":false,"dockWidgets":[]}'))
        compare(store.showFolderTitles, false)
        compare(store.dockWidgets.length, 0)
        verify(store.patch({dockSize: "large"}))
        compare(store.dockSize, "large")
        compare(store.showFolderTitles, false)
        verify(!store.patch({unknownPreference: true}))
        verify(!store.restore('broken JSON'))
        compare(store.dockSize, "large")
        verify(store.error !== "")
        verify(store.restore('{"dockPosition":"right"}'))
        compare(store.dockPosition, "right")
    }
}
