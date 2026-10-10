// DockMatcher.js — Window matching, icon resolution, and dock item builder for Omarchy Dock

.pragma library
.import "AppIdentity.js" as Identity
.import "AppCatalog.js" as Catalog
.import "DesktopCatalog.js" as Entries

var stripDesktop = Entries.stripDesktop;
var cleanWindowAppId = Entries.cleanWindowAppId;
var normalizeKey = Entries.normalizeKey;
var extractChromeDomain = Entries.extractChromeDomain;
var toArray = Entries.toArray;
var unwrapEntry = Entries.unwrapEntry;
var getEntryExec = Entries.getEntryExec;
var createDesktopEntryIndex = Entries.createIndex;
var findEntryFast = Entries.find;

function findEntry(desktopEntries, appId) {
    return Entries.find(Entries.createIndex(desktopEntries), appId);
}


var KNOWN_APP_DEFAULTS = Catalog.KNOWN_APP_DEFAULTS;
var FALLBACK_ICON_CANDIDATES = Catalog.FALLBACK_ICON_CANDIDATES;

function getCandidates(rawIcon, icon, appId) {
    var list = [];
    function add(c) {
        if (!c) return;
        var s = String(c).trim();
        if (s.length === 0) return;
        if (list.indexOf(s) === -1) list.push(s);
        var sLow = s.toLowerCase();
        if (list.indexOf(sLow) === -1) list.push(sLow);

        if (s.indexOf("_") !== -1) {
            var hyp = s.replace(/_/g, "-");
            if (list.indexOf(hyp) === -1) list.push(hyp);
            var hypLow = hyp.toLowerCase();
            if (list.indexOf(hypLow) === -1) list.push(hypLow);
        }
        if (s.indexOf("-") !== -1) {
            var und = s.replace(/-/g, "_");
            if (list.indexOf(und) === -1) list.push(und);
            var undLow = und.toLowerCase();
            if (list.indexOf(undLow) === -1) list.push(undLow);
        }
        if (s.indexOf(" ") !== -1) {
            var dash = s.replace(/\s+/g, "-");
            if (list.indexOf(dash) === -1) list.push(dash);
            var dashLow = dash.toLowerCase();
            if (list.indexOf(dashLow) === -1) list.push(dashLow);
        }

        var cleaned = cleanWindowAppId(s);
        if (cleaned && cleaned !== s) {
            if (list.indexOf(cleaned) === -1) list.push(cleaned);
            var cleanedLow = cleaned.toLowerCase();
            if (list.indexOf(cleanedLow) === -1) list.push(cleanedLow);
        }

        var firstToken = (cleaned || s).split(/[\s\-_]+/)[0];
        if (firstToken && firstToken.length >= 3 && firstToken !== s && firstToken !== cleaned) {
            if (list.indexOf(firstToken) === -1) list.push(firstToken);
            var firstLow = firstToken.toLowerCase();
            if (list.indexOf(firstLow) === -1) list.push(firstLow);
        }
    }
    add(rawIcon);
    add(icon);
    add(appId);
    var clean = String(appId || rawIcon || "").toLowerCase().replace(/\.desktop$/, "");
    add(clean);
    var cleanedAppId = cleanWindowAppId(appId);
    if (cleanedAppId) add(cleanedAppId);
    var withoutPrefix = clean.replace(/^(org|com|io|net|dev)\.[^.]+\./, "");
    add(withoutPrefix);
    var lastPart = clean.split(".").pop();
    add(lastPart);

    if (clean.indexOf("com.transmissionbt.transmission") === 0 || clean === "transmission" || clean === "transmission-gtk" || clean === "transmission-qt") {
        add("transmission-gtk");
        add("transmission");
        add("com.transmissionbt.Transmission");
        add("transmission-qt");
    }

    if (clean.indexOf("steam_app_") === 0) {
        var sGameId = clean.replace(/^steam_app_/, "");
        add("steam_icon_" + sGameId);
        add("steam_app_" + sGameId);
        add("steam");
    }

    if (FALLBACK_ICON_CANDIDATES[clean]) {
        var fb = FALLBACK_ICON_CANDIDATES[clean];
        for (var i = 0; i < fb.length; i++) add(fb[i]);
    }
    if (FALLBACK_ICON_CANDIDATES[lastPart]) {
        var fb2 = FALLBACK_ICON_CANDIDATES[lastPart];
        for (var j = 0; j < fb2.length; j++) add(fb2[j]);
    }

    if (clean.indexOf("portal") !== -1 || clean.indexOf("file-chooser") !== -1 || clean.indexOf("filechooser") !== -1 || clean.indexOf("file-picker") !== -1) {
        add("document-open");
        add("document-save-as");
        add("document-save");
        add("system-file-manager");
        add("org.gnome.Nautilus");
        add("org.kde.dolphin");
        add("file-manager");
        add("folder");
    }

    if (clean.indexOf("org.omarchy.") === 0 || clean.indexOf("omarchy-") === 0 || clean.indexOf("omarchy.") === 0) {
        if (clean.indexOf("update") !== -1) {
            add("system-software-update");
            add("software-update-available");
            add("update-manager");
            add("system-upgrade");
        }
        if (clean.indexOf("config") !== -1 || clean.indexOf("settings") !== -1 || clean.indexOf("edit") !== -1) {
            add("preferences-system");
            add("configuration-section");
            add("system-settings");
            add("preferences-desktop");
        }
        if (clean.indexOf("about") !== -1 || clean.indexOf("info") !== -1) {
            add("help-about");
            add("help");
            add("dialog-information");
        }
        add("omarchy");
        add("utilities-terminal");
        add("com.mitchellh.ghostty");
        add("ghostty");
    }

    var chromeDom = extractChromeDomain(clean);
    if (chromeDom) {
        add(chromeDom);
        if (FALLBACK_ICON_CANDIDATES[chromeDom]) {
            var fbc = FALLBACK_ICON_CANDIDATES[chromeDom];
            for (var fc = 0; fc < fbc.length; fc++) add(fbc[fc]);
        }
        var domParts = chromeDom.split(".");
        for (var dp = 0; dp < domParts.length; dp++) {
            var dpart = domParts[dp];
            if (dpart.length >= 3 && dpart !== "com" && dpart !== "org" && dpart !== "net") {
                add(dpart);
                if (FALLBACK_ICON_CANDIDATES[dpart]) {
                    var fbd = FALLBACK_ICON_CANDIDATES[dpart];
                    for (var fd = 0; fd < fbd.length; fd++) add(fbd[fd]);
                }
            }
        }
    }
    return list;
}

var _diskIcons = {};

function setDiskIcons(iconsObj) {
    _diskIcons = {};
    if (iconsObj && typeof iconsObj === "object") {
        for (var k in iconsObj) {
            var path = iconsObj[k];
            if (path && typeof path === "string") {
                _diskIcons[k] = path;
                var low = k.toLowerCase();
                if (!_diskIcons[low]) _diskIcons[low] = path;
                if (low.indexOf(".") !== -1) {
                    var parts = low.split(".");
                    var last = parts[parts.length - 1];
                    if (last && !_diskIcons[last]) _diskIcons[last] = path;
                }
            }
        }
    }
}

function getDiskIcon(name) {
    if (!name) return "";
    var s = String(name).trim();
    if (s.indexOf("://") >= 0) return s;
    if (s.charAt(0) === "/") return "file://" + s;

    var low = s.toLowerCase();
    if (_diskIcons[low]) return "file://" + _diskIcons[low];
    if (_diskIcons[s]) return "file://" + _diskIcons[s];

    var cleaned = cleanWindowAppId(s);
    if (cleaned && _diskIcons[cleaned]) return "file://" + _diskIcons[cleaned];
    if (cleaned && _diskIcons[cleaned.toLowerCase()]) return "file://" + _diskIcons[cleaned.toLowerCase()];

    var stripped = stripDesktop(s);
    if (stripped && _diskIcons[stripped]) return "file://" + _diskIcons[stripped];
    if (stripped && _diskIcons[stripped.toLowerCase()]) return "file://" + _diskIcons[stripped.toLowerCase()];

    if (low.indexOf(".") !== -1) {
        var dotParts = low.split(".");
        var dotLast = dotParts[dotParts.length - 1];
        if (dotLast && _diskIcons[dotLast]) return "file://" + _diskIcons[dotLast];
    }

    return "";
}

function resolveIcon(entry, appId, appLibrary) {
    if (entry && entry.iconSource && entry.iconSource.length > 0 && entry.iconSource.indexOf("application-x-executable") === -1) {
        return entry.iconSource;
    }
    if (entry && entry.icon) {
        var iconVal = String(entry.icon).trim();
        if (iconVal.indexOf("file://") === 0 || iconVal.indexOf("image://") === 0) return iconVal;
        if (iconVal.charAt(0) === "/") return "file://" + iconVal;
        var diskFound = getDiskIcon(iconVal);
        if (diskFound) return diskFound;
        if (appLibrary && typeof appLibrary.iconSource === "function") {
            var src = appLibrary.iconSource(iconVal);
            if (src && src.length > 0 && src.indexOf("application-x-executable") === -1) return src;
        }
        return iconVal;
    }
    var id = stripDesktop(appId);
    var diskIdFound = getDiskIcon(id);
    if (diskIdFound) return diskIdFound;

    if (appLibrary && typeof appLibrary.iconSource === "function") {
        var candidates = getCandidates(entry ? entry.icon : "", "", id);
        for (var i = 0; i < candidates.length; i++) {
            var cand = candidates[i];
            if (cand.indexOf("file://") === 0 || cand.indexOf("image://") === 0) return cand;
            if (cand.charAt(0) === "/") return "file://" + cand;
            var cDisk = getDiskIcon(cand);
            if (cDisk) return cDisk;
            var cSrc = appLibrary.iconSource(cand);
            if (cSrc && cSrc.length > 0 && cSrc.indexOf("application-x-executable") === -1) return cSrc;
        }

        // Try hyphenated/spaced variations (e.g. "Google Maps" -> "google-maps")
        var hyp = id.toLowerCase().replace(/\s+/g, "-");
        var hypDisk = getDiskIcon(hyp);
        if (hypDisk) return hypDisk;
        var src3 = appLibrary.iconSource(hyp);
        if (src3 && src3.length > 0 && src3.indexOf("application-x-executable") === -1) return src3;

        var spc = id.toLowerCase().replace(/[-_]+/g, " ");
        var spcDisk = getDiskIcon(spc);
        if (spcDisk) return spcDisk;
        var src4 = appLibrary.iconSource(spc);
        if (src4 && src4.length > 0 && src4.indexOf("application-x-executable") === -1) return src4;
    } else {
        var cands = getCandidates(entry ? entry.icon : "", "", id);
        for (var ci = 0; ci < cands.length; ci++) {
            var cd = getDiskIcon(cands[ci]);
            if (cd) return cd;
        }
    }
    return id || "application-x-executable";
}

function isBrowserApp(id) {
    var s = String(id || "").toLowerCase();
    return s === "google-chrome" || s === "google-chrome-stable" || s === "chromium" || s === "brave" || s === "brave-browser" || s === "brave-origin" || s === "microsoft-edge" || s === "opera" || s === "vivaldi" || s === "yandex-browser" || s === "yandex-browser-stable" || s === "ru.yandex.desktop.browser";
}

var KNOWN_TERMINALS = [
    "ghostty", "com.mitchellh.ghostty", "kitty", "alacritty", "org.alacritty",
    "foot", "footclient", "wezterm", "org.wezfurlong.wezterm", "wezterm-gui",
    "xterm", "uxterm", "gnome-terminal", "org.gnome.terminal", "konsole",
    "org.kde.konsole", "xfce4-terminal", "tilix", "com.gexperts.tilix", "st",
    "simple-terminal", "urxvt", "rxvt", "rxvt-unicode", "terminator",
    "lxterminal", "contour", "rio", "blackbox", "com.raggesilver.blackbox",
    "ptyxis", "org.gnome.ptyxis", "tabby", "hyper", "warp", "warp-terminal"
];

function isTerminalApp(id, entry) {
    if (!id && !entry) return false;
    var s = String(id || "").toLowerCase().trim();
    if (s.slice(-8) === ".desktop") s = s.slice(0, -8);
    for (var i = 0; i < KNOWN_TERMINALS.length; i++) {
        if (s === KNOWN_TERMINALS[i]) return true;
    }
    if (entry) {
        if (Array.isArray(entry.categories) && entry.categories.indexOf("TerminalEmulator") !== -1) {
            return true;
        }
        if (typeof entry.categories === "string" && entry.categories.indexOf("TerminalEmulator") !== -1) {
            return true;
        }
        var gen = String(entry.genericName || "").toLowerCase();
        if (gen.indexOf("terminal emulator") !== -1 || gen === "terminal") {
            return true;
        }
    }
    return false;
}

var IGNORED_COMMAND_PREFIXES = [
    "su" + "do", "doas", "pk" + "exec", "pacman", "yay", "paru", "apt", "dnf", "zypper",
    "cargo", "npm", "pnpm", "yarn", "bun", "git", "make", "ninja", "cmake",
    "pip", "python", "python3", "node", "go", "rustc", "gcc", "clang",
    "find", "grep", "cat", "less", "more", "tail", "journal" + "ctl", "system" + "ctl",
    "sh", "bash", "zsh", "fish", "exec", "run", "echo", "rm", "cp", "mv",
    "which", "whereis", "man", "info", "curl", "wget", "tar", "unzip", "zip",
    "home", "user", "usr", "etc", "bin", "tmp", "var", "opt", "desktop", "documents", "downloads", "music", "pictures", "videos"
];

var KNOWN_CLI_COMMANDS = [
    "yazi", "nvim", "neovim", "vim", "nano", "micro", "helix", "hx", "emacs", "kakoune", "kak", "amp",
    "btop", "htop", "top", "bottom", "btm", "glances", "bashtop", "bpytop", "nvtop", "gotop",
    "ranger", "superfile", "broot", "vifm", "nnn", "lf", "fff", "mc", "midnight-commander", "clifm",
    "lazygit", "lazydocker", "tig", "gitui", "k9s", "ox", "bandwhich", "gping",
    "ncmpcpp", "cmus", "mocp", "cava", "cliamp", "rmpc", "spotify-tui", "spt", "mopidy", "musikcube",
    "weechat", "irssi", "profanity", "neomutt", "mutt", "aerc", "gomuks", "senpai",
    "tmux", "zellij", "cmatrix", "pipes.sh", "fastfetch", "neofetch", "cbonsai", "tty-clock", "peaclock", "termshark", "glow", "curseofwar"
];

function extractCliApp(title, desktopEntries) {
    if (!title) return "";
    var raw = String(title).toLowerCase().trim();
    var rawTokens = raw.split(/[\s:,\-_/\\()\[\]{}|]+/);
    var tokens = [];
    for (var k = 0; k < rawTokens.length; k++) {
        if (rawTokens[k].length > 0) tokens.push(rawTokens[k]);
    }
    if (tokens.length === 0) return "";

    var first = tokens[0];
    if (IGNORED_COMMAND_PREFIXES.indexOf(first) === -1 && KNOWN_CLI_COMMANDS.indexOf(first) !== -1) {
        if (first === "neovim" || first === "vim") return "nvim";
        if (first === "hx") return "helix";
        if (first === "btm") return "bottom";
        return first;
    }

    // Check all tokens in title for known CLI app names
    for (var t = 0; t < tokens.length; t++) {
        var tok = tokens[t];
        if (IGNORED_COMMAND_PREFIXES.indexOf(tok) !== -1) continue;
        if (KNOWN_CLI_COMMANDS.indexOf(tok) !== -1) {
            if (tok === "neovim" || tok === "vim") return "nvim";
            if (tok === "hx") return "helix";
            if (tok === "btm") return "bottom";
            return tok;
        }
    }

    // Dynamic scanning: check if any token in title matches an installed desktop entry.
    // Match only on the entry's id or exec binary, never on its display Name: a title
    // word that equals a GUI app's Name (e.g. "Claude" while Claude Code runs in a
    // terminal) does not mean that app is what is running in the terminal.
    if (desktopEntries) {
        var catalog = desktopEntries.records ? desktopEntries : Entries.createIndex(desktopEntries);
        var list = catalog.records;
        var scanLimit = Math.min(tokens.length, 3);
        for (var i = 0; i < scanLimit; i++) {
            var token = tokens[i];
            if (token.length < 3 || IGNORED_COMMAND_PREFIXES.indexOf(token) !== -1 || isTerminalApp(token)) continue;
            for (var d = 0; d < list.length; d++) {
                var de = list[d];
                var deId = de.id;
                if ((token === deId || token === de.execBase) && !isTerminalApp(deId, de.source)) {
                    return deId || token;
                }
            }
        }
    }

    // Special title patterns like 'filename - NVIM' or '[No Name] - NVIM'
    if (raw.indexOf("nvim") !== -1 && tokens.indexOf("nvim") !== -1) {
        return "nvim";
    }

    // Special patterns for cliamp Winamp scrolling marquee ("really whips", "whips the terminal's ass", "cliamp", "it really", "really whip", "ass.")
    if (raw.indexOf("whips") !== -1 || raw.indexOf("terminal's ass") !== -1 || raw.indexOf("cliamp") !== -1 || raw.indexOf("really whip") !== -1 || raw.indexOf("it really") !== -1 || raw.indexOf("ass.") !== -1) {
        return "cliamp";
    }

    return "";
}

// =========================================================================
// Predictive Launch Hint — instant CLI app icon appearance
// When a CLI app is launched, we record the set of currently open windows
// (knownBefore). When a NEW terminal window opens that was NOT in knownBefore,
// it is immediately identified as the launched CLI app without waiting
// for the window title to update.
// =========================================================================
var _pendingCliHint = null; // { appId: string, timestamp: number, knownBefore: Array, appliedToTop: Object|null }

function setPendingCliHint(appId, knownWindowsList) {
    if (!appId) return;
    var clean = stripDesktop(appId).toLowerCase();
    var cleanNorm = normalizeKey(clean);
    var isCli = (KNOWN_CLI_COMMANDS.indexOf(clean) !== -1 || KNOWN_CLI_COMMANDS.indexOf(cleanNorm) !== -1 || clean === "cliamp" || cleanNorm === "cliamp");
    if (isCli) {
        var known = [];
        if (Array.isArray(knownWindowsList)) {
            for (var i = 0; i < knownWindowsList.length; i++) {
                if (knownWindowsList[i]) known.push(knownWindowsList[i]);
            }
        }
        var targetCmd = clean;
        for (var k = 0; k < KNOWN_CLI_COMMANDS.length; k++) {
            if (KNOWN_CLI_COMMANDS[k] === clean || KNOWN_CLI_COMMANDS[k] === cleanNorm) {
                targetCmd = KNOWN_CLI_COMMANDS[k];
                break;
            }
        }
        _pendingCliHint = {
            appId: targetCmd,
            timestamp: Date.now(),
            knownBefore: known,
            appliedToTop: null
        };
    }
}

function getPendingCliHint() {
    if (!_pendingCliHint) return null;
    if (Date.now() - _pendingCliHint.timestamp > 6000) {
        _pendingCliHint = null;
        return null;
    }
    return _pendingCliHint;
}

function clearPendingCliHint() {
    _pendingCliHint = null;
}

var _detectedCliApps = []; // array of detected CLI command strings from /proc, e.g. ["cliamp", "btop"]
var _detectedCliTimestamp = 0;

function setDetectedCliApps(apps) {
    if (Array.isArray(apps)) {
        _detectedCliApps = apps.slice();
        _detectedCliTimestamp = Date.now();
    }
}

function getDetectedCliApps() {
    if (Date.now() - _detectedCliTimestamp > 15000) {
        _detectedCliApps = [];
    }
    return _detectedCliApps;
}

var _stickyCliByTopId = {}; // topId -> cliApp
var _nextTopId = 1;

function hasRealDesktopEntry(entries, appId) {
    if (!entries || !appId) return false;
    var target = stripDesktop(appId).toLowerCase().trim();
    var catalog = entries.records ? entries : Entries.createIndex(entries);
    return catalog.records.some(function(entry) { return entry.id === target || entry.name === target || entry.execBase === target; });
}

function normalizeWindow(toplevel) {
    if (!toplevel) return null;
    var appClass = String(toplevel.appId || "").toLowerCase().trim();
    var cleanClass = stripDesktop(appClass);
    var baseClass = cleanWindowAppId(cleanClass).toLowerCase();
    return {
        source: toplevel, appClass: appClass,
        title: String(toplevel.title || "").toLowerCase().trim(),
        cleanClass: cleanClass, baseClass: baseClass,
        firstToken: baseClass.split(/[\s\-_]+/)[0],
        hyphenated: baseClass.indexOf(" ") !== -1 ? baseClass.replace(/\s+/g, "-") : "",
        domain: extractChromeDomain(appClass),
        classKey: normalizeKey(cleanClass), baseKey: normalizeKey(baseClass)
    };
}

function matchToplevel(toplevel, appId, entry, desktopEntries, cachedCliApp) {
    return matchWindow(normalizeWindow(toplevel), appId, Entries.normalizeEntry(entry), desktopEntries, cachedCliApp);
}

function matchWindow(window, appId, metadata, desktopEntries, cachedCliApp) {
    if (!window) return false;
    var entry = metadata ? metadata.source : null;
    var appClass = window.appClass;
    var title = window.title;
    var cleanId = stripDesktop(appId).toLowerCase().trim();

    if (!cleanId && !entry) return false;
    if (!appClass) return false;

    var appClassClean = window.cleanClass;
    var baseAppClass = window.baseClass;
    var firstClassToken = window.firstToken;
    var hypClass = window.hyphenated;

    var chromeDom = window.domain;
    var isWebAppWindow = (chromeDom.length > 0);

    // If this window is a Chrome Web App (e.g. chrome-maps.google.com__-Default):
    // Standard web browser dock items (Google Chrome, Chromium, Brave) should NOT swallow it!
    if (isWebAppWindow && isBrowserApp(cleanId)) {
        return false;
    }

    // Terminal CLI / TUI application matching:
    // If a window is running in a terminal emulator (e.g. foot, ghostty, kitty):
    if (isTerminalApp(appClass, null)) {
        var cliApp = (cachedCliApp !== undefined) ? cachedCliApp : extractCliApp(title, desktopEntries);
        // Case A: Dock item is a specific CLI app (e.g. yazi, nvim, btop):
        if (cliApp && !isTerminalApp(cleanId, entry)) {
            var normCliApp = normalizeKey(cliApp);
            var normTargetId = normalizeKey(cleanId);
            if (cleanId === cliApp || normTargetId === normCliApp) return true;
            if (entry) {
                var eId = metadata.id;
                var eName = metadata.name;
                if (eId === cliApp || normalizeKey(eId) === normCliApp) return true;
                if (eName === cliApp || normalizeKey(eName) === normCliApp) return true;
            }
        }
        // Case B: Dock item is a generic terminal emulator, but window is running a dedicated CLI app:
        if (cliApp && isTerminalApp(cleanId, entry)) {
            return false;
        }
        // Case C: Dock item IS a terminal emulator, and window is a generic terminal session (no dedicated CLI app):
        if (!cliApp && isTerminalApp(cleanId, entry)) {
            return true;
        }
    }

    // Transmission GTK Wayland dynamic app ID matching (com.transmissionbt.transmission_<pid>_<random>)
    if (appClass.indexOf("com.transmissionbt.transmission") === 0 || cleanId.indexOf("com.transmissionbt.transmission") === 0) {
        var isTransDockItem = (cleanId === "transmission" || cleanId === "transmission-gtk" || cleanId === "transmission-qt" || cleanId.indexOf("com.transmissionbt.transmission") === 0);
        if (isTransDockItem) return true;
        if (entry) {
            var trEntryId = metadata.id;
            var trEntryExec = metadata.execBase;
            if (trEntryId === "transmission-gtk" || trEntryId === "transmission-qt" || trEntryId === "transmission" ||
                trEntryExec === "transmission-gtk" || trEntryExec === "transmission-qt" || trEntryExec === "transmission") {
                return true;
            }
        }
    }

    // Steam game matching (e.g. steam_app_1700)
    if (appClass.indexOf("steam_app_") === 0) {
        if (cleanId === "steam") return false;
        var steamGameId = appClass.replace(/^steam_app_/, "");
        if (cleanId === appClass || cleanId === ("steam_icon_" + steamGameId)) return true;
        if (entry) {
            var stExec = metadata.exec;
            var stIcon = metadata.icon;
            if (stExec.indexOf("rungameid/" + steamGameId) !== -1 || stIcon === "steam_icon_" + steamGameId || stIcon === "steam_app_" + steamGameId) {
                return true;
            }
        }
    }

    // Yandex Browser matching
    if (appClass === "yandex-browser" || appClass === "yandex-browser-stable") {
        if (cleanId === "yandex-browser" || cleanId === "yandex-browser-stable" || cleanId === "ru.yandex.desktop.browser") return true;
        if (entry) {
            var yId = metadata.id;
            var yExec = metadata.execBase;
            if (yId === "yandex-browser" || yId === "ru.yandex.desktop.browser" || yExec === "yandex-browser-stable" || yExec === "yandex-browser") return true;
        }
    }

    // 1. Direct class match (with and without .desktop / .exe)
    if (cleanId && (appClass === cleanId || appClassClean === cleanId || baseAppClass === cleanId || hypClass === cleanId || appClass === (cleanId + ".desktop") || appClass === (cleanId + ".exe"))) return true;

    // 2. Normalized match
    var normClass = window.classKey;
    var normBaseClass = window.baseKey;
    var normId = cleanId ? normalizeKey(cleanId) : "";
    if (normId.length > 0 && (normClass === normId || normBaseClass === normId)) return true;
    if (normId.length > 0 && firstClassToken.length >= 3 && normalizeKey(firstClassToken) === normId) return true;

    // 3. Entry ID, Name, Icon and Exec match
    if (entry) {
        var entryId = metadata.id;
        var normEntryId = metadata.idKey;
        if (entryId && (appClass === entryId || appClassClean === entryId || baseAppClass === entryId || hypClass === entryId || normClass === normEntryId || normBaseClass === normEntryId)) return true;
        if (entryId && firstClassToken.length >= 3 && (firstClassToken === entryId || normalizeKey(firstClassToken) === normEntryId)) return true;

        var entryName = metadata.name;
        if (entryName) {
            var normEntryName = metadata.nameKey;
            if (normClass === normEntryName || normBaseClass === normEntryName) return true;
            if (firstClassToken.length >= 3 && normalizeKey(firstClassToken) === normEntryName) return true;
            var nameTokens = metadata.nameTokens;
            for (var nt = 0; nt < nameTokens.length; nt++) {
                if (nameTokens[nt] === appClassClean || nameTokens[nt] === baseAppClass || (nameTokens[nt].length >= 3 && nameTokens[nt] === firstClassToken)) return true;
            }
        }

        if (metadata.icon && (normClass === metadata.iconKey || normBaseClass === metadata.iconKey)) return true;

        var entryExecStr = metadata.exec;
        if (entryExecStr) {
            var execBase = metadata.execBase;
            if (execBase && execBase !== "env" && execBase !== "sh" && execBase !== "bash" && execBase !== "flatpak" && execBase !== "bwrap" && execBase !== "wine" && execBase !== "uwsm-app" && !isWebAppWindow) {
                if (appClass === execBase || appClassClean === execBase || baseAppClass === execBase || (firstClassToken.length >= 3 && firstClassToken === execBase)) return true;
            }
        }
    }

    // 4. Chrome / Web App Matching
    if (isWebAppWindow) {
        var cEntryExec = metadata ? metadata.exec : "";
        if (entry && cEntryExec && cEntryExec.indexOf(chromeDom) !== -1) return true;
        if (entry && entry.id && entry.id.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (cleanId && cleanId.indexOf(chromeDom) !== -1) return true;
        if (normId.length > 0 && normId.indexOf(normalizeKey(chromeDom)) !== -1) return true;

        var candidateTokens = (metadata ? metadata.tokens : []).concat(Entries.tokens(cleanId));
        var parts = Entries.domainParts(chromeDom, 3);
        if (parts.some(function(part) { return Entries.tokenMatches(candidateTokens, part); })) return true;
    }

    // 5. Window Title Match for web apps / webapp launchers
    if (metadata && metadata.exec.indexOf("omarchy-launch-webapp") !== -1) {
        if (entry.name && title.length > 0) {
            var normName = normalizeKey(entry.name);
            var normTitle = normalizeKey(title);
            if (normTitle.indexOf(normName) !== -1 || normName.indexOf(normTitle) !== -1) return true;
        }
    }

    // 6. Normalized prefix matches (e.g., com.mitchellh.ghostty <-> ghostty, org.kde.dolphin <-> dolphin)
    if (!isWebAppWindow) {
        var appClassShort = appClass.replace(/^(org|com|io|net|dev)\.[^.]+\./, "").replace(/\.desktop$/, "");
        if (cleanId && appClassShort === cleanId) return true;

        var cleanIdShort = cleanId.replace(/^(org|com|io|net|dev)\.[^.]+\./, "");
        if (appClass === cleanIdShort || appClassShort === cleanIdShort) return true;
    }

    return false;
}

function toCanonical(str) { return Identity.toCanonical(str); }

function getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId) {
    if (!badgeCounts || typeof badgeCounts !== "object") return { count: 0, hasUrgent: false };
    var rawKeys = [
        appId,
        entry ? entry.id : "",
        entry ? stripDesktop(entry.id) : "",
        desktopId,
        desktopId ? stripDesktop(desktopId) : "",
        name,
        entry ? entry.name : "",
        entry ? getEntryExec(entry) : ""
    ];
    var keys = [];
    for (var k = 0; k < rawKeys.length; k++) {
        var r = String(rawKeys[k] || "").trim();
        if (!r) continue;
        if (keys.indexOf(r) === -1) keys.push(r);
        var canon = toCanonical(r);
        if (canon && keys.indexOf(canon) === -1) keys.push(canon);
    }

    var count = 0;
    var isUrgent = false;
    for (var i = 0; i < keys.length; i++) {
        var raw = String(keys[i] || "").trim().toLowerCase();
        if (!raw) continue;
        if (badgeCounts[raw] != null && Number(badgeCounts[raw]) > count) {
            count = Number(badgeCounts[raw]);
        }
        if (urgentCounts && urgentCounts[raw] === true) {
            isUrgent = true;
        }
        var clean = raw.replace(/[^a-z0-9]/g, "");
        if (clean && badgeCounts[clean] != null && Number(badgeCounts[clean]) > count) {
            count = Number(badgeCounts[clean]);
        }
        if (clean && urgentCounts && urgentCounts[clean] === true) {
            isUrgent = true;
        }
    }
    return { count: count, hasUrgent: isUrgent };
}

// The Hyprland address of one of a dock item's windows, empty when the window
// is not in Hyprland's list any more. A dock icon numbers its windows in its
// own sticky creation order, while the helper script resolves them against
// Hyprland's client list, and that list reorders on its own — a lock screen, a
// workspace move or a restore from the scratchpad is enough to swap two entries
// around. A position sent across that gap names whichever window happens to sit
// there; an address names the window itself.
function hyprAddressFor(toplevel, hyprToplevels) {
    if (!toplevel || !hyprToplevels || typeof hyprToplevels.length !== "number") return "";
    for (var i = 0; i < hyprToplevels.length; i++) {
        var ht = hyprToplevels[i];
        if (!ht) continue;
        if (ht === toplevel || ht.wayland === toplevel) {
            var addr = String(ht.address || "");
            if (!addr) return "";
            return addr.indexOf("0x") === 0 ? addr : ("0x" + addr);
        }
    }
    return "";
}

// Keep focus history separate from the stable order used by previews and cycling.
// Object identity prevents a new window with a reused title/address inheriting focus.
function rememberWindowFocus(history, liveWindows, activeToplevel) {
    var live = toArray(liveWindows);
    var previous = Array.isArray(history) ? history : [];
    var next = [];
    if (activeToplevel && live.indexOf(activeToplevel) !== -1) next.push(activeToplevel);
    for (var i = 0; i < previous.length; i++) {
        var top = previous[i];
        if (top && live.indexOf(top) !== -1 && next.indexOf(top) === -1) next.push(top);
    }
    return next;
}

function collectMatchingToplevels(appId, entry, entries, toplevels, assignedTops, toplevelCliApps, activeToplevel, isTopMinimizedFn, getTopKeyFn, focusedWindowHistory) {
    return collectWindows(appId, Entries.normalizeEntry(entry), entries, toArray(toplevels).map(normalizeWindow), assignedTops, toplevelCliApps, activeToplevel, isTopMinimizedFn, getTopKeyFn, focusedWindowHistory);
}

function collectWindows(appId, metadata, entries, windows, assignedTops, toplevelCliApps, activeToplevel, isTopMinimizedFn, getTopKeyFn, focusedWindowHistory) {
    var matching = [];
    var isAnyActive = false;
    var activeIdx = 0;
    var minCount = 0;

    for (var t = 0; t < windows.length; t++) {
        var window = windows[t];
        var top = window ? window.source : null;
        var tKey = getTopKeyFn ? getTopKeyFn(top, t) : (top ? (String(top.appId || "") + "___" + String(top.title || "") + "___" + t) : ("top_" + t));
        var cliApp = toplevelCliApps ? toplevelCliApps[tKey] : undefined;

        if (!assignedTops[tKey] && matchWindow(window, appId, metadata, entries, cliApp)) {
            matching.push(top);
            assignedTops[tKey] = true;

            var isMin = isTopMinimizedFn ? isTopMinimizedFn(top) : false;
            if (isMin) {
                minCount++;
            } else {
                try {
                    if (activeToplevel && top === activeToplevel) {
                        isAnyActive = true;
                        activeIdx = matching.length - 1;
                    }
                } catch (e) {}
            }
        }
    }

    var isAllMin = (matching.length > 0 && minCount === matching.length);
    if (isAllMin) isAnyActive = false;
    if (!isAnyActive && Array.isArray(focusedWindowHistory)) {
        for (var h = 0; h < focusedWindowHistory.length; h++) {
            var recentIndex = matching.indexOf(focusedWindowHistory[h]);
            if (recentIndex !== -1) {
                activeIdx = recentIndex;
                break;
            }
        }
    }

    return {
        matching: matching,
        isActive: isAnyActive,
        isMinimized: isAllMin,
        activeTopIndex: activeIdx,
        windowCount: matching.length
    };
}

function buildDockItems(pinnedList, toplevelsList, activeToplevel, desktopEntries, appLibrary, badgeCounts, urgentCounts, maxItems, minimizedToplevels, focusedWindowHistory) {
    var pinned = Array.isArray(pinnedList) ? pinnedList : [];
    var toplevels = toArray(toplevelsList);
    var windows = toplevels.map(normalizeWindow);
    var entryIndex = createDesktopEntryIndex(desktopEntries);
    var entries = entryIndex.list;
    var minList = Array.isArray(minimizedToplevels) ? minimizedToplevels : [];

    var items = [];
    var assignedTops = {};

    function isTopMinimized(top) {
        if (!top) return false;
        if (top.minimized === true) return true;
        for (var m = 0; m < minList.length; m++) {
            if (minList[m] === top) return true;
            try {
                if (minList[m] && minList[m].wayland === top) return true;
            } catch (e) {}
        }
        return false;
    }

    for (var init_t = 0; init_t < toplevels.length; init_t++) {
        var tObj = toplevels[init_t];
        if (tObj && typeof tObj === "object") {
            try {
                if (!tObj._dockTopId) {
                    tObj._dockTopId = (tObj.address ? String(tObj.address) : ("win_" + (_nextTopId++)));
                }
            } catch (e) {}
        }
    }

    function getTopKey(top, idx) {
        if (!top) return "top_" + idx;
        try {
            if (top._dockTopId) return top._dockTopId;
            if (top.address) return String(top.address);
        } catch (e) {}
        var app = "";
        try {
            app = String(top.appId || "");
        } catch (e) {}
        return app + "___" + idx;
    }

    function entryFor(id) {
        return findEntryFast(entryIndex, id);
    }

    // Precalculate CLI app recognition once per toplevel to avoid O(P * T * E) repeated loops
    // Predictive Launch Hint & Real-Time /proc Scanning:
    //   1. Detect CLI apps from window titles (extractCliApp)
    //   2. If not in title, apply predictive launch hint from dock click
    //   3. If not in title, apply background /proc scanner results (detects CLI apps launched from menu/CLI)
    //   4. When extractCliApp confirms the real title, clear the hint.
    var toplevelCliApps = {};
    var hint = getPendingCliHint();
    var detectedCliList = getDetectedCliApps();
    for (var tc = 0; tc < toplevels.length; tc++) {
        var topObj = toplevels[tc];
        if (topObj && isTerminalApp(topObj.appId || "")) {
            var tk = getTopKey(topObj, tc);
            var title = String(topObj.title || "");
            var detected = extractCliApp(title, entryIndex);

            // Check sticky window cache for persistent player/app matching (vital for Winamp marquee!)
            if (!detected && _stickyCliByTopId[tk]) {
                detected = _stickyCliByTopId[tk];
            }

            if (!detected && hint) {
                var wasAlreadyOpen = false;
                if (hint.knownBefore && Array.isArray(hint.knownBefore)) {
                    for (var kb = 0; kb < hint.knownBefore.length; kb++) {
                        if (hint.knownBefore[kb] === topObj) {
                            wasAlreadyOpen = true;
                            break;
                        }
                    }
                }
                if (!wasAlreadyOpen && (!hint.appliedToTop || hint.appliedToTop === topObj)) {
                    detected = hint.appId;
                    hint.appliedToTop = topObj;
                }
            }
            if (!detected && detectedCliList.length > 0) {
                for (var d = 0; d < detectedCliList.length; d++) {
                    var candCli = detectedCliList[d];
                    if (candCli) {
                        detected = candCli;
                        break;
                    }
                }
            }

            if (detected) {
                _stickyCliByTopId[tk] = detected;
            }

            if (detected && hint && (hint.appliedToTop === topObj || detected === hint.appId)) {
                if (extractCliApp(topObj.title || "", entryIndex)) {
                    clearPendingCliHint();
                    hint = null;
                }
            }
            toplevelCliApps[tk] = detected;
        }
    }

    // Purge closed windows from sticky cache
    var liveTopKeys = {};
    for (var ltk = 0; ltk < toplevels.length; ltk++) {
        if (toplevels[ltk]) liveTopKeys[getTopKey(toplevels[ltk], ltk)] = true;
    }
    for (var cachedKey in _stickyCliByTopId) {
        if (!liveTopKeys[cachedKey]) {
            delete _stickyCliByTopId[cachedKey];
        }
    }

    // Every app (pinned, running or inside a folder) uses the same model shape.
    function appItem(appId, entry, isPinned, fallbackName, fallbackClass) {
        var result = collectWindows(appId, Entries.recordFor(entryIndex, entry), entryIndex, windows, assignedTops, toplevelCliApps, activeToplevel, isTopMinimized, getTopKey, focusedWindowHistory);
        var name = entry && entry.name ? entry.name : (fallbackName || appId || "App");
        var desktopId = entry && entry.id ? entry.id : appId;
        var badge = getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId);
        return {
            id: appId, appId: appId, desktopId: desktopId,
            exec: getEntryExec(entry),
            appClass: result.matching.length ? (result.matching[0].appId || "") : (fallbackClass || ""),
            name: name, icon: resolveIcon(entry, appId, appLibrary),
            rawIcon: entry && entry.icon ? entry.icon : (appId || "application-x-executable"),
            iconSource: entry && entry.iconSource ? entry.iconSource : "",
            isStack: false, isPinned: isPinned, isDuplicate: false,
            isRunning: result.windowCount > 0, isActive: result.isActive,
            isMinimized: result.isMinimized, activeTopIndex: result.activeTopIndex,
            windowCount: result.windowCount, badgeCount: badge.count,
            hasUrgent: badge.hasUrgent, toplevels: result.matching
        };
    }

    // 1. Process Pinned Items
    for (var i = 0; i < pinned.length; i++) {
        var p = pinned[i];
        if (p && typeof p === "object" && p.isStack) {
            var subApps = [];
            var isAnySubRunning = false;
            var isAnySubActive = false;

            for (var s = 0; s < p.apps.length; s++) {
                var sAppId = stripDesktop(p.apps[s]);
                var sEntry = entryFor(sAppId);
                var subApp = appItem(sAppId, sEntry, true);
                if (subApp.isRunning) isAnySubRunning = true;
                if (subApp.isActive) isAnySubActive = true;
                subApps.push(subApp);
            }

            var totalStackBadge = 0;
            var hasStackUrgent = false;
            for (var sb = 0; sb < subApps.length; sb++) {
                totalStackBadge += (subApps[sb].badgeCount || 0);
                if (subApps[sb].hasUrgent) hasStackUrgent = true;
            }

            items.push({
                id: p.id || ("stack_" + i),
                name: p.name || "Folder",
                icon: p.icon || "folder",
                isStack: true,
                isPinned: true,
                isDuplicate: false,
                isRunning: isAnySubRunning,
                isActive: isAnySubActive,
                subApps: subApps,
                badgeCount: totalStackBadge,
                hasUrgent: hasStackUrgent,
                activeTopIndex: 0,
                windowCount: 0
            });
        } else {
            var appId = stripDesktop(typeof p === "string" ? p : (p && p.id ? p.id : ""));
            if (!appId) continue;

            var entry = entryFor(appId);
            items.push(appItem(appId, entry, true));
        }
    }

    // 2. Process Running Unpinned Toplevels (Stop if limit reached)
    for (var j = 0; j < toplevels.length; j++) {
        if (maxItems && maxItems > 0 && items.length >= maxItems) {
            break;
        }

        var topItem = toplevels[j];
        if (!topItem) continue;
        var topItemKey = getTopKey(topItem, j);
        if (assignedTops[topItemKey]) continue;

        var rAppId = "";
        var rTitle = "";
        try {
            rAppId = topItem.appId || "";
            rTitle = topItem.title || "";
        } catch (e) {}

        // If window is running inside a terminal emulator and executes a recognized CLI app with a valid installed desktop entry:
        if (isTerminalApp(rAppId)) {
            var rCliApp = (toplevelCliApps[topItemKey] !== undefined) ? toplevelCliApps[topItemKey] : extractCliApp(rTitle, entries);
            if (rCliApp && !isTerminalApp(rCliApp) && hasRealDesktopEntry(entryIndex, rCliApp)) {
                rAppId = rCliApp;
            } else if (!rTitle || rTitle === rAppId || rTitle === "foot" || rTitle === "ghostty" || rTitle === "kitty" || rTitle === "alacritty" || rTitle === "terminal") {
                var isPinnedTerm = false;
                for (var pt = 0; pt < pinned.length; pt++) {
                    var pinnedId = (typeof pinned[pt] === "string") ? pinned[pt] : (pinned[pt] && pinned[pt].id ? pinned[pt].id : "");
                    if (isTerminalApp(stripDesktop(pinnedId))) {
                        isPinnedTerm = true;
                        break;
                    }
                }
                if (isPinnedTerm) {
                    continue;
                }
            }
        }

        var origAppClass = rAppId;
        var rEntry = entryFor(rAppId);
        if (rEntry && rEntry.id) {
            rAppId = stripDesktop(rEntry.id);
        }
        var running = appItem(rAppId, rEntry, false, rTitle, origAppClass);
        if (running.isRunning) items.push(running);
    }

    return items;
}
