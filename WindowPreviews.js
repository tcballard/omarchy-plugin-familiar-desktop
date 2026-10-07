.pragma library

// Only pass registered Wayland toplevels to ScreencopyView. Hyprland-only
// (including hidden/minimised) records retain their title and activation target.
function describe(top, live, hypr) {
    var ht = null
    for (var i = 0; i < hypr.length; i++) {
        if (hypr[i] && (hypr[i] === top || hypr[i].wayland === top)) { ht = hypr[i]; break }
    }
    var wayland = live.indexOf(top) >= 0 ? top : (ht && live.indexOf(ht.wayland) >= 0 ? ht.wayland : null)
    var name = ht && ht.workspace ? String(ht.workspace.name || ht.workspace.id || "") : ""
    var minimized = !!(top && top.minimized) || name.indexOf("special:") === 0
    return { target: top, capture: minimized ? null : wayland,
        title: String((top && top.title) || "Untitled window"),
        workspace: minimized ? "Minimised" : name ? "Workspace " + name : "Open window" }
}

function currentIndex(app, target) {
    return app && app.toplevels ? app.toplevels.indexOf(target) : -1
}
