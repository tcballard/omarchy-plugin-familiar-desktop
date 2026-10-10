import QtQuick
import Quickshell.Io
import "SettingsSchema.js" as Schema

// One instance in the hosted service owns all durable preferences.
Item {
    id: store
    required property string path
    property string error: ""
    property string profile: "general"
    property string shortcutLabels: "standard"
    property bool dockEnabled: true
    property bool fileShortcutsEnabled: false
    property string dockBackgroundOpacity: "theme"
    property string dockSize: "default"
    property string dockPosition: "auto"
    property string titlebarSize: "default"
    property bool titlebarsEnabled: false
    property string titlebarMode: "theme"
    property string titlebarStyle: "windows"
    property string titlebarExclusions: ""
    property string visibilityMode: "always"
    property string preferredVisibilityMode: "hover"
    property bool overlayMode: false
    property string visibleWorkspace: "all"
    property int autohideEdgeDepth: 1
    property bool showFolderTitles: true
    property bool showBadges: true
    property bool windowPreviews: true
    property bool glassmorphism: false
    property real blurOpacity: 0.68
    property bool widgetsEnabled: true
    property string appMenuPosition: "left"
    property string widgetPosition: "right"
    property var dockWidgets: ["omarchy.apps"]
    property var widgetSavedPositions: ({})

    function restore(text) {
        try {
            var raw = text && text.trim() ? JSON.parse(text) : {};
            if (!raw || typeof raw !== "object" || Array.isArray(raw))
                throw new Error("Expected a settings object");
            var values = Schema.normalize(raw);
            for (var key in values)
                store[key] = values[key];
            error = "";
            return true;
        } catch (e) {
            error = "Could not read Familiar settings; your file was preserved.";
            return false;
        }
    }
    function snapshot() {
        return {
            "profile": store.profile,
            "shortcutLabels": store.shortcutLabels,
            "dockEnabled": store.dockEnabled,
            "fileShortcutsEnabled": store.fileShortcutsEnabled,
            "dockBackgroundOpacity": store.dockBackgroundOpacity,
            "dockSize": store.dockSize,
            "dockPosition": store.dockPosition,
            "titlebarSize": store.titlebarSize,
            "titlebarsEnabled": store.titlebarsEnabled,
            "titlebarMode": store.titlebarMode,
            "titlebarStyle": store.titlebarStyle,
            "titlebarExclusions": store.titlebarExclusions,
            "visibilityMode": store.visibilityMode,
            "preferredVisibilityMode": store.preferredVisibilityMode,
            "overlayMode": store.overlayMode,
            "visibleWorkspace": store.visibleWorkspace,
            "autohideEdgeDepth": store.autohideEdgeDepth,
            "showFolderTitles": store.showFolderTitles,
            "showBadges": store.showBadges,
            "windowPreviews": store.windowPreviews,
            "glassmorphism": store.glassmorphism,
            "blurOpacity": store.blurOpacity,
            "widgetsEnabled": store.widgetsEnabled,
            "appMenuPosition": store.appMenuPosition,
            "widgetPosition": store.widgetPosition,
            "dockWidgets": store.dockWidgets,
            "widgetSavedPositions": store.widgetSavedPositions
        };
    }
    function patch(changes) {
        var values = snapshot();
        for (var key in changes) {
            if (!Object.prototype.hasOwnProperty.call(values, key))
                return false;
            values[key] = changes[key];
        }
        values = Schema.normalize(values);
        if (!save(values))
            return false;
        for (var field in values)
            store[field] = values[field];
        return true;
    }
    function save(values) {
        // A malformed external file is never replaced by defaults.
        try {
            var text = file.text();
            var raw = text && text.trim() ? JSON.parse(text) : {};
            if (!raw || typeof raw !== "object" || Array.isArray(raw))
                throw new Error("Expected a settings object");
            file.setText(Schema.encode(raw, values || snapshot()));
            error = "";
            return true;
        } catch (e) {
            error = "Could not save Familiar settings; your file was preserved.";
            return false;
        }
    }
    FileView {
        id: file
        objectName: "settings-file"
        path: store.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: store.restore(text())
        onFileChanged: reload()
    }
}
