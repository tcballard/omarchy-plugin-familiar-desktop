.pragma library
.import "../DockSettings.js" as Policy
.import "../DockWidgets.js" as Widgets
.import "../ShortcutLabels.js" as Labels

// The complete persisted contract. Unknown fields survive round trips.
function normalize(raw) {
    var s = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    var result = Policy.normalize(s)
    result.shortcutLabels = Labels.normalize(s.shortcutLabels)
    result.dockEnabled = s.dockEnabled === undefined || [true, "true", 1, "1"].indexOf(s.dockEnabled) !== -1
    result.fileShortcutsEnabled = s.fileShortcutsEnabled === true
    result.preferredVisibilityMode = ["hover", "keybind"].indexOf(s.preferredVisibilityMode) !== -1
        ? s.preferredVisibilityMode : (["hover", "keybind"].indexOf(result.visibilityMode) !== -1 ? result.visibilityMode : "hover")
    var depth = parseInt(s.autohideEdgeDepth, 10)
    result.autohideEdgeDepth = !isNaN(depth) && depth >= 1 && depth <= 64 ? depth : 1
    result.showFolderTitles = s.showFolderTitles !== false
    result.showBadges = s.showBadges !== false
    result.windowPreviews = s.windowPreviews !== false
    result.glassmorphism = s.glassmorphism === true
    var blur = Number(s.blurOpacity)
    result.blurOpacity = isFinite(blur) && blur >= 0.1 && blur <= 1 ? blur : 0.68
    result.widgetsEnabled = s.widgetsEnabled !== false
    result.appMenuPosition = s.appMenuPosition === "right" ? "right" : "left"
    result.widgetPosition = s.widgetPosition === "left" ? "left" : "right"
    result.dockWidgets = Array.isArray(s.dockWidgets) ? Widgets.normalizeDockWidgets(s.dockWidgets) : ["omarchy.apps"]
    result.widgetSavedPositions = s.widgetSavedPositions && typeof s.widgetSavedPositions === "object" && !Array.isArray(s.widgetSavedPositions) ? s.widgetSavedPositions : {}
    return result
}

function encode(previous, values) {
    var result = Object.assign({}, previous || {}, normalize(values))
    result.autohide = Policy.legacyAutohide(result.visibilityMode)
    return JSON.stringify(result, null, 2) + "\n"
}
