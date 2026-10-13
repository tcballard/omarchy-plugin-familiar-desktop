// Runtime icon lookup shared by dock items and folder previews.
// Dependencies are explicit so theme lookup can also be tested without a shell.
.pragma library

// Never hand a network URL to Qt's Image loader in the shared shell.
function localSource(source) {
    if (typeof source !== "string") return "";
    if (/^\/(?!\/)/.test(source)) return "file://" + source;
    if (/^(file:\/\/\/|qrc:\/|image:\/\/)/i.test(source)) return source;
    return "";
}

function iconIdentifier(value) {
    return typeof value === "string" && value.length > 0 && !/[\/:\\\x00-\x1f\x7f]/.test(value);
}

function resolve(item, lookup) {
    function generic() {
        return localSource(lookup.iconPath("application-x-executable")) || "file:///usr/share/pixmaps/omarchy.png";
    }
    if (!item) return generic();
    var raw = typeof item === "string" ? item : (item.rawIcon || item.icon || item.appId || item.id || "");
    if (!raw) return generic();
    var identifierOnly = typeof item !== "string" && (item.iconIdentifierOnly || (!item.rawIcon && !item.icon));
    if (identifierOnly && !iconIdentifier(raw)) return generic();
    if (!identifierOnly && localSource(raw)) return localSource(raw);
    if (!iconIdentifier(raw)) return generic();
    var candidates = typeof item === "string"
        ? lookup.candidates(item, item, item)
        : lookup.candidates(item.rawIcon, item.icon, item.appId || item.id);
    function useful(source) {
        return localSource(source) && source.indexOf("application-x-executable") === -1;
    }
    var library = lookup.library;
    for (var i = 0; i < candidates.length; i++) {
        var candidate = candidates[i];
        if (!iconIdentifier(candidate)) continue;
        var lower = candidate.toLowerCase();
        var disk = lookup.diskIcon(candidate) || lookup.diskIcon(lower);
        if (localSource(disk)) return localSource(disk);
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
    if (identifierOnly || !lookup.friendlyFallback) return generic();
    if (library && typeof library.iconSource === "function") {
        var fallback = library.iconSource("omarchy") || library.iconSource("ghostty") || library.iconSource("utilities-terminal");
        if (localSource(fallback)) return localSource(fallback);
    }
    return localSource(lookup.iconPath("omarchy")) || localSource(lookup.iconPath("com.mitchellh.ghostty"))
        || localSource(lookup.iconPath("utilities-terminal")) || generic();
}
