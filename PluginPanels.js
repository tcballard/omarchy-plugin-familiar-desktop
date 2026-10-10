// Registered shell panels share org.quickshell; their exact title identifies
// the plugin. Keep that display identity separate from the real window object.
.pragma library

function entriesFor(widgets, iconFor) {
    var entries = [];
    for (var id in (widgets || {})) {
        if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(id)) continue;
        var meta = widgets[id] ? widgets[id].metadata : null;
        if (!meta || !meta.displayName) continue;
        var icon = String(meta.icon || (iconFor ? iconFor(id) : "") || "");
        entries.push({
            id: id, name: String(meta.displayName), pluginId: String(meta.pluginId || id),
            icon: icon, iconGlyph: icon.length <= 3 && icon.codePointAt(0) >= 128 ? icon : ""
        });
    }
    return entries;
}

function resolve(toplevel, entries) {
    if (!toplevel) return null;
    var appId = String(toplevel.appId || "").toLowerCase().trim();
    var title = String(toplevel.title || "").toLowerCase().trim();
    var sharedShell = appId === "org.quickshell" || appId === "quickshell" || appId === "qs";
    var found = null;
    for (var i = 0; i < (entries || []).length; i++) {
        var entry = entries[i];
        if (appId === entry.id.toLowerCase()) return entry;
        if (!sharedShell || !title || title !== entry.name.toLowerCase().trim()) continue;
        // Two registered plugins with the same title cannot be distinguished.
        if (found) return null;
        found = entry;
    }
    return found;
}
