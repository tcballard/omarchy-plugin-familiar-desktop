import QtQuick

// Session interaction state. Views request transitions; selections resolve from
// the current model so refreshing or reordering items cannot leave stale menus.
QtObject {
    id: interaction
    property var items: []
    property var selection: null // { kind: "app" | "folder" | "folder-menu", id }
    property var editor: null // { kind: "items" | "title", returnToItems? }

    function findSelectedIndex() {
        if (!selection) return -1
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (item && (selection.kind === "app" ? !item.isStack && item.appId === selection.id : item.isStack && item.id === selection.id)) return i
        }
        return -1
    }
    readonly property int selectedIndex: findSelectedIndex()
    readonly property var selectedItem: selectedIndex >= 0 ? items[selectedIndex] : null
    readonly property string popup: selection && selectedItem ? selection.kind : "none"
    readonly property var folder: popup === "folder" ? selectedItem : null
    readonly property var folderMenu: popup === "folder-menu" ? selectedItem : null
    readonly property var app: popup === "app" ? selectedItem : null
    readonly property bool editingItems: !!editor && (editor.kind === "items" || editor.returnToItems === true)
    readonly property bool renamingFolder: !!folder && !!editor && editor.kind === "title"

    function select(kind, item) {
        if (!item || (kind === "app" ? item.isStack || !item.appId : !item.isStack || !item.id)) return
        var id = kind === "app" ? item.appId : item.id
        if (selection && selection.kind === kind && selection.id === id) {
            dismissPopup()
            return
        }
        renameFolder(false)
        selection = { kind: kind, id: id }
    }
    function toggleFolder(item) { select("folder", item) }
    function toggleFolderMenu(item) { select("folder-menu", item) }
    function toggleApp(item) { select("app", item) }

    function dismissPopup() {
        renameFolder(false)
        selection = null
    }
    function dismissFolder() { if (selection && selection.kind === "folder") dismissPopup() }
    function dismissFolderMenu() { if (selection && selection.kind === "folder-menu") dismissPopup() }
    function dismissApp() { if (selection && selection.kind === "app") dismissPopup() }
    function dismiss() {
        selection = null
        editor = null
    }

    function setEditing(enabled) {
        if (enabled && popup !== "folder") dismissPopup()
        editor = enabled ? { kind: "items" } : null
    }
    function renameFolder(enabled) {
        if (enabled) {
            if (folder && !renamingFolder) editor = { kind: "title", returnToItems: editingItems }
        } else if (editor && editor.kind === "title") {
            editor = editor.returnToItems ? { kind: "items" } : null
        }
    }

    onItemsChanged: {
        if (!selection) return
        var index = findSelectedIndex()
        var item = index >= 0 ? items[index] : null
        if (!item || (selection.kind !== "app" && (!item.isStack || !item.subApps || item.subApps.length < 2))) dismissPopup()
    }
}
