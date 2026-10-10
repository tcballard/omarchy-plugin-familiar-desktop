import QtQuick
import QtTest
import "../components"

TestCase {
    name: "DockInteraction"
    DockInteraction { id: interaction }
    property var app: ({ appId: "editor", name: "Editor", isStack: false })
    property var folder: ({ id: "work", name: "Work", isStack: true, subApps: ["editor", "browser"] })
    property var otherFolder: ({ id: "play", name: "Play", isStack: true, subApps: ["game", "music"] })

    function init() {
        interaction.dismiss()
        interaction.items = [app, folder, otherFolder]
    }
    function test_onlyOnePopup() {
        interaction.toggleApp(app)
        compare(interaction.popup, "app")
        interaction.toggleFolder(folder)
        compare(interaction.popup, "folder")
        compare(interaction.app, null)
        interaction.toggleFolderMenu(otherFolder)
        compare(interaction.popup, "folder-menu")
        compare(interaction.folder, null)
        interaction.toggleFolderMenu(otherFolder)
        compare(interaction.popup, "none")
    }
    function test_differentFoldersNeverShareUndefinedAppIds() {
        interaction.toggleFolder(folder)
        interaction.toggleFolder(otherFolder)
        compare(interaction.folder.id, "play")
        interaction.toggleFolderMenu(folder)
        interaction.toggleFolderMenu(otherFolder)
        compare(interaction.folderMenu.id, "play")
    }
    function test_reorderAndRefreshUseLiveItems() {
        interaction.toggleFolder(folder)
        var refreshed = { id: "work", name: "Updated", isStack: true, subApps: ["browser", "editor"] }
        interaction.items = [otherFolder, app, refreshed]
        compare(interaction.selectedIndex, 2)
        compare(interaction.folder, refreshed)
        interaction.toggleApp(app)
        var refreshedApp = { appId: "editor", name: "Updated editor", isStack: false, windowCount: 2 }
        interaction.items = [refreshedApp, otherFolder, refreshed]
        compare(interaction.selectedIndex, 0)
        compare(interaction.app, refreshedApp)
    }
    function test_removedItemsAndDissolvedFoldersDismiss() {
        interaction.toggleFolder(folder)
        interaction.renameFolder(true)
        interaction.items = [app]
        compare(interaction.popup, "none")
        compare(interaction.renamingFolder, false)
        interaction.items = [folder]
        interaction.toggleFolderMenu(folder)
        interaction.items = [{id: "work", isStack: true, subApps: ["editor"]}]
        compare(interaction.selection, null)
        interaction.items = [app]
        interaction.toggleApp(app)
        interaction.items = []
        compare(interaction.selection, null)
    }
    function test_renameRequiresFolderAndReturnsToEditing() {
        interaction.renameFolder(true)
        compare(interaction.renamingFolder, false)
        interaction.toggleFolder(folder)
        interaction.setEditing(true)
        interaction.renameFolder(true)
        compare(interaction.renamingFolder, true)
        compare(interaction.editingItems, true)
        interaction.renameFolder(false)
        compare(interaction.renamingFolder, false)
        compare(interaction.editingItems, true)
        interaction.dismiss()
        compare(interaction.editingItems, false)
        compare(interaction.popup, "none")
    }
    function test_editingDismissesMenusButPreservesOpenFolder() {
        interaction.toggleApp(app)
        interaction.setEditing(true)
        compare(interaction.popup, "none")
        interaction.toggleFolder(folder)
        interaction.setEditing(true)
        compare(interaction.folder, folder)
        interaction.setEditing(false)
        compare(interaction.folder, folder)
    }
}
