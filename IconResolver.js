// Runtime icon lookup shared by dock items and folder previews.
// Dependencies are explicit so theme lookup can also be tested without a shell.
.pragma library

function resolve(item, lookup) {
    function generic() {
        return lookup.iconPath("application-x-executable") || (lookup.friendlyFallback ? "file:///usr/share/pixmaps/omarchy.png" : "");
    }
    if (!item) return generic();
    var raw = typeof item === "string" ? item : (item.rawIcon || item.icon || item.appId || item.id || "");
    if (!raw) return generic();
    if (raw.indexOf("://") >= 0) return raw;
    if (raw.indexOf("/") === 0) return "file://" + raw;
    var candidates = typeof item === "string"
        ? lookup.candidates(item, item, item)
        : lookup.candidates(item.rawIcon, item.icon, item.appId || item.id);
    function useful(source) {
        return source && source.length > 0 && source.indexOf("application-x-executable") === -1;
    }
    var library = lookup.library;
    for (var i = 0; i < candidates.length; i++) {
        var candidate = candidates[i];
        if (candidate.indexOf("://") >= 0) return candidate;
        if (candidate.indexOf("/") === 0) return "file://" + candidate;
        var lower = candidate.toLowerCase();
        var disk = lookup.diskIcon(candidate) || lookup.diskIcon(lower);
        if (disk) return disk;
        if (library && typeof library.iconSource === "function") {
            var source = library.iconSource(candidate);
            if (useful(source)) return source;
            if (lower !== candidate) {
                source = library.iconSource(lower);
                if (useful(source)) return source;
            }
        }
        var themed = lookup.iconPath(candidate);
        if (useful(themed)) return themed;
        themed = lookup.iconPath(lower);
        if (useful(themed)) return themed;
    }
    // App tiles retain their existing friendly fallback; folder previews use generic.
    if (!lookup.friendlyFallback) return generic();
    if (library && typeof library.iconSource === "function") {
        var fallback = library.iconSource("omarchy") || library.iconSource("ghostty") || library.iconSource("utilities-terminal");
        if (fallback) return fallback;
    }
    return lookup.iconPath("omarchy") || lookup.iconPath("com.mitchellh.ghostty")
        || lookup.iconPath("utilities-terminal") || generic();
}
