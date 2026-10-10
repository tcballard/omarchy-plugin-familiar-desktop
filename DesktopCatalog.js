// Desktop-entry metadata and the ordered lookup rules used by the dock.
// Always return the original entry: normalized keys are never launch IDs.
.pragma library
.import "AppCatalog.js" as Defaults

function stripDesktop(id) {
    var value = String(id == null ? "" : id).trim();
    if (value.slice(-8).toLowerCase() === ".desktop") value = value.slice(0, -8);
    if (value.slice(-4).toLowerCase() === ".exe") value = value.slice(0, -4);
    return value;
}

function cleanWindowAppId(id) {
    return stripDesktop(id)
        .replace(/\s*[-_–—]?\s*(?:xwayland|wayland|x11)\s*$/i, "")
        .replace(/\s*\((?:xwayland|wayland|x11)\)\s*$/i, "")
        .trim().replace(/\s+v?[0-9]+(?:\.[0-9]+)*[a-z]?\s*$/i, "").trim();
}

function normalizeKey(value) {
    return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function extractChromeDomain(appClass) {
    var value = String(appClass || "").toLowerCase();
    if (["brave-browser", "brave-origin", "chromium-browser", "chrome-browser", "yandex-browser", "yandex-browser-stable"].indexOf(value) !== -1) return "";
    if (!/^(chrome|chromium|brave|edge)-/.test(value)) return "";
    var domain = value.replace(/^(chrome|chromium|brave|edge)-/, "")
        .replace(/__.*$/, "").replace(/_\/.*$/, "").replace(/^-+/, "");
    return domain === "browser" ? "" : domain;
}

function toArray(list) {
    if (Array.isArray(list)) return list;
    var result = [];
    if (list && typeof list.length === "number") {
        for (var i = 0; i < list.length; i++) result.push(list[i]);
    }
    return result;
}

function unwrapEntry(entry) {
    if (!entry) return null;
    return entry && entry.entry && typeof entry.entry === "object" ? entry.entry : entry;
}

function getEntryExec(entry) {
    return entry ? String(entry.execString || entry.exec || "") : "";
}

function tokens(value) { return value.split(/[\s\-_\.]+/); }

function normalizeEntry(entry) {
    entry = unwrapEntry(entry);
    if (!entry) return null;
    var id = stripDesktop(entry.id).toLowerCase();
    var name = String(entry.name || "").toLowerCase();
    var icon = String(entry.icon || "").toLowerCase();
    var exec = getEntryExec(entry).trim().toLowerCase();
    return {
        source: entry, id: id, name: name, icon: icon, exec: exec,
        execBase: exec.split(/\s+/)[0].split("/").pop(),
        idKey: normalizeKey(id), nameKey: normalizeKey(name), iconKey: normalizeKey(icon),
        nameTokens: tokens(name), tokens: tokens(id).concat(tokens(name), tokens(icon))
    };
}

function putFirst(map, key, entry) {
    if (key && !map[key]) map[key] = entry;
}

function createIndex(desktopEntries) {
    var records = toArray(desktopEntries).map(normalizeEntry).filter(function(entry) { return entry !== null; });
    var index = { records: records, list: [], byId: Object.create(null), byName: Object.create(null), byNorm: Object.create(null), byExec: Object.create(null) };
    records.forEach(function(record) {
        var entry = record.source;
        index.list.push(entry);
        putFirst(index.byId, record.id, entry);
        putFirst(index.byName, record.name, entry);
        putFirst(index.byName, cleanWindowAppId(record.name), entry);
        putFirst(index.byNorm, record.idKey, entry);
        putFirst(index.byNorm, record.nameKey, entry);
        putFirst(index.byNorm, normalizeKey(cleanWindowAppId(record.name)), entry);
        putFirst(index.byExec, record.execBase, entry);
    });
    // An icon alias may fill a missing key, but cannot replace an app identity.
    records.forEach(function(record) {
        putFirst(index.byId, record.icon, record.source);
        putFirst(index.byNorm, record.iconKey, record.source);
    });
    return index;
}

function recordFor(index, entry) {
    for (var i = 0; i < index.records.length; i++) {
        if (index.records[i].source === entry) return index.records[i];
    }
    return normalizeEntry(entry);
}

function directMatch(index, target) {
    return index.byId[target] || index.byName[target] || index.byExec[target] || index.byNorm[normalizeKey(target)] || null;
}

var APP_ALIASES = [
    { prefix: "com.transmissionbt.transmission", ids: ["transmission-gtk", "transmission-qt", "transmission", "com.transmissionbt.transmission"], execs: ["transmission-gtk", "transmission-qt", "transmission"] },
    { names: ["yandex-browser", "yandex-browser-stable", "ru.yandex.desktop.browser"], ids: ["yandex-browser", "ru.yandex.desktop.browser"], execs: ["yandex-browser-stable", "yandex-browser"] }
];
var IGNORED_DOMAIN_PARTS = ["com", "org", "net", "web", "app", "google", "yandex", "microsoft", "apple"];

function domainParts(domain, minLength) {
    return domain.split(".").filter(function(part) { return part.length >= minLength && IGNORED_DOMAIN_PARTS.indexOf(part) === -1; });
}

function tokenMatches(tokens, part) {
    return tokens.some(function(token) {
        return token === part || (part.endsWith("s") && token === part.slice(0, -1)) || (token.endsWith("s") && token.slice(0, -1) === part);
    });
}

function find(index, appId) {
    if (!index) return null;
    var target = stripDesktop(appId).toLowerCase();
    if (!target) return null;
    var found = directMatch(index, target);
    if (found) return found;

    for (var a = 0; a < APP_ALIASES.length; a++) {
        var alias = APP_ALIASES[a];
        if (!(alias.prefix && target.indexOf(alias.prefix) === 0) && !(alias.names && alias.names.indexOf(target) !== -1)) continue;
        for (var i = 0; i < alias.ids.length; i++) {
            if (index.byId[alias.ids[i]]) return index.byId[alias.ids[i]];
        }
        for (var e = 0; e < alias.execs.length; e++) {
            if (index.byExec[alias.execs[e]]) return index.byExec[alias.execs[e]];
        }
    }

    var steamGame = target.indexOf("steam_app_") === 0;
    if (steamGame) {
        var gameId = target.slice(10);
        for (var s = 0; s < index.records.length; s++) {
            var game = index.records[s];
            if (game.exec.indexOf("rungameid/" + gameId) !== -1 || game.icon === "steam_icon_" + gameId || game.icon === "steam_app_" + gameId) return game.source;
        }
    }

    // A web app's site outranks the browser executable shared by its launchers.
    var domain = extractChromeDomain(target);
    if (domain) {
        for (var c = 0; c < index.records.length; c++) {
            var web = index.records[c];
            if (web.exec.indexOf(domain) !== -1 || web.id.indexOf(domain) !== -1) return web.source;
        }
    }
    var cleanTarget = cleanWindowAppId(target);
    var firstToken = cleanTarget.split(/[\s\-_]+/)[0];
    var variants = [target];
    if (!steamGame || (cleanTarget !== "steam" && cleanTarget !== "steam_app")) variants.push(cleanTarget);
    if (!steamGame && !domain && firstToken.length >= 3 && firstToken !== "steam") variants.push(firstToken);
    if (cleanTarget.indexOf(" ") !== -1) variants.push(cleanTarget.replace(/\s+/g, "-"));
    for (var v = 1; v < variants.length; v++) {
        found = directMatch(index, variants[v]);
        if (found) return found;
    }

    if (!steamGame) {
        for (var d = 0; d < variants.length; d++) {
            var known = Defaults.KNOWN_APP_DEFAULTS[variants[d]];
            if (known && index.byId[stripDesktop(known.id).toLowerCase()]) return index.byId[stripDesktop(known.id).toLowerCase()];
        }
    }

    // Only the exceptional rules scan the already-normalized records.
    var suffixes = [target.replace(/^(org|com|io|net|dev)\.[^.]+\./i, ""), target.split(".").pop()];
    if (suffixes[0] !== target || suffixes[1] !== target) {
        for (var r = 0; r < index.records.length; r++) {
            var record = index.records[r];
            if (suffixes.indexOf(record.id) !== -1 || suffixes.indexOf(record.name) !== -1 || suffixes.indexOf(record.execBase) !== -1) return record.source;
        }
    }
    var parts = domainParts(domain, 1);
    if (parts.length) {
        for (var w = 0; w < index.records.length; w++) {
            var candidate = index.records[w];
            if (parts.every(function(part) { return tokenMatches(candidate.tokens, part); })) return candidate.source;
        }
    }
    variants.push(domain);
    for (var f = 0; f < variants.length; f++) {
        if (Defaults.KNOWN_APP_DEFAULTS[variants[f]]) return Defaults.KNOWN_APP_DEFAULTS[variants[f]];
    }
    return null;
}
