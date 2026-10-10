import "../AppIdentity.js" as Identity
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons

Item {
    id: tracker

    property var shell: null
    property var knownWindows: []

    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/familiar-desktop-badges.json"

    // Only notification events persist. Titles are a live snapshot, not increments.
    property var notificationCounts: ({})
    property var canonicalCounts: ({})
    property var canonicalUrgent: ({})
    property var lastNotifTimestamps: ({})

    PersistentProperties {
        id: persisted
        reloadableId: "familiar-desktop-notification-tracker"
        property var counts: ({})
        property var urgent: ({})
        property bool loaded: false
    }

    FileView {
        id: badgeStateFile
        path: tracker.statePath
        onLoaded: tracker.loadDiskState()
    }

    Process {
        id: saveProc
        running: false
        property string payload: ""
        onStarted: {
            write(payload)
            stdinEnabled = false
            payload = ""
        }
    }

    Timer {
        id: saveDebounceTimer
        interval: 400
        repeat: false
        onTriggered: {
            persisted.counts = tracker.notificationCounts
            persisted.urgent = tracker.canonicalUrgent
            persisted.loaded = true
            try {
                var jsonStr = JSON.stringify({
                    counts: tracker.notificationCounts,
                    urgent: tracker.canonicalUrgent
                })
                if (saveProc.running) { saveDebounceTimer.restart(); return }
                saveProc.command = [Qt.resolvedUrl("../bin/familiar-desktop").toString().replace(/^file:\/\//, ""), "badges", "save", "--stdin"]
                saveProc.payload = jsonStr
                saveProc.stdinEnabled = true
                saveProc.running = true
            } catch (e) {}
        }
    }

    function scheduleSave() {
        persisted.counts = tracker.notificationCounts
        persisted.urgent = tracker.canonicalUrgent
        persisted.loaded = true
        saveDebounceTimer.restart()
    }

    function loadDiskState() {
        // Priority 1: In-process PersistentProperties (survives theme reload)
        if (persisted.loaded || (persisted.counts && typeof persisted.counts === "object" && Object.keys(persisted.counts).length > 0)) {
            notificationCounts = Object.assign({}, persisted.counts || {})
            canonicalUrgent = Object.assign({}, persisted.urgent || {})
            persisted.loaded = true
            refreshCounts()
            return
        }
        // Priority 2: Disk file (survives full shell restart and reboot)
        try {
            var raw = badgeStateFile.text()
            if (raw) {
                var data = JSON.parse(raw)
                if (data && typeof data === "object" && data.counts) {
                    // Legacy files mixed both sources. Preserve those counts until
                    // the usual focus/clear action rather than discard real events.
                    notificationCounts = Object.assign({}, data.counts || {})
                    canonicalUrgent = Object.assign({}, data.urgent || {})
                    persisted.counts = notificationCounts
                    persisted.urgent = canonicalUrgent
                    persisted.loaded = true
                    refreshCounts()
                }
            }
        } catch (e) {}
    }

    signal badgeChanged()

    function refreshCounts() {
        var next = Object.assign({}, notificationCounts)
        for (var key in titleExtractedBadges) {
            next[key] = Math.max(Number(next[key]) || 0, titleExtractedBadges[key])
        }
        canonicalCounts = next
        badgeChanged()
    }

    // -------------------------------------------------------------------------
    // 1. Canonical Key Normalization & Matching Engine (Desktop + Web Apps)
    // -------------------------------------------------------------------------
    function toCanonical(str) {
        return Identity.toCanonical(str)
    }

    function getCandidateKeys(appId, entry, name, desktopId) {
        var keys = []
        if (appId) keys.push(String(appId))
        if (desktopId) keys.push(String(desktopId))
        if (entry && entry.id) keys.push(String(entry.id))
        if (entry && entry.name) keys.push(String(entry.name))
        var entryExec = entry ? (entry.execString || entry.exec || "") : ""
        if (entryExec) keys.push(String(entryExec))
        if (name) keys.push(String(name))

        var canonicalSet = []
        for (var i = 0; i < keys.length; i++) {
            var raw = String(keys[i]).trim().toLowerCase()
            if (raw && canonicalSet.indexOf(raw) === -1) canonicalSet.push(raw)
            var clean = raw.replace(/[^a-z0-9]/g, "")
            if (clean && canonicalSet.indexOf(clean) === -1) canonicalSet.push(clean)
            var c = toCanonical(keys[i])
            if (c && canonicalSet.indexOf(c) === -1) canonicalSet.push(c)
        }
        return canonicalSet
    }

    // -------------------------------------------------------------------------
    // 2. Querying Badge Count & Urgency
    // -------------------------------------------------------------------------
    function getBadgeCount(appId, entry, name, desktopId) {
        var keys = getCandidateKeys(appId, entry, name, desktopId)
        var maxCount = 0
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (canonicalCounts[k] != null && Number(canonicalCounts[k]) > maxCount) {
                maxCount = Number(canonicalCounts[k])
            }
        }
        return maxCount
    }

    function getBadgeInfo(appId, entry, name, desktopId) {
        var keys = getCandidateKeys(appId, entry, name, desktopId)
        var maxCount = 0
        var isUrgent = false
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (canonicalCounts[k] != null && Number(canonicalCounts[k]) > maxCount) {
                maxCount = Number(canonicalCounts[k])
            }
            if (canonicalUrgent[k] === true) {
                isUrgent = true
            }
        }
        return { count: maxCount, hasUrgent: isUrgent }
    }

    // -------------------------------------------------------------------------
    // 3. Increment & Deduplication Engine
    // -------------------------------------------------------------------------
    function incrementBadge(appKey, delta, isUrgent) {
        if (!appKey) return
        var rawKey = String(appKey).trim().toLowerCase()
        var cKey = toCanonical(appKey)
        var cleanKey = rawKey.replace(/[^a-z0-9]/g, "")
        if (!cKey && !rawKey) return

        var targetKey = cKey || rawKey
        var current = notificationCounts[targetKey] ? Number(notificationCounts[targetKey]) : 0
        var add = (delta != null && delta > 0) ? delta : 1

        var nextCounts = Object.assign({}, notificationCounts)
        var nextUrgent = Object.assign({}, canonicalUrgent)
        var nextTimestamps = Object.assign({}, lastNotifTimestamps)

        var keysToSet = [targetKey, rawKey, cleanKey, cKey]
        for (var i = 0; i < keysToSet.length; i++) {
            var k = keysToSet[i]
            if (!k) continue
            nextCounts[k] = current + add
            if (isUrgent) nextUrgent[k] = true
            nextTimestamps[k] = Date.now()
        }

        notificationCounts = nextCounts
        canonicalUrgent = nextUrgent
        lastNotifTimestamps = nextTimestamps

        refreshCounts()
        scheduleSave()
    }

    // -------------------------------------------------------------------------
    // 4. Reliable Badge Clearing (Window Focus, Click & Dismissal)
    // -------------------------------------------------------------------------
    function clearBadge(itemData) {
        if (!itemData) return
        var keysToCheck = [
            itemData.id,
            itemData.appId,
            itemData.desktopId,
            itemData.name
        ]
        if (itemData.isStack && itemData.subApps) {
            for (var i = 0; i < itemData.subApps.length; i++) {
                var sub = itemData.subApps[i]
                keysToCheck.push(sub.id, sub.appId, sub.desktopId, sub.name)
            }
        }

        clearBadgeKeys(keysToCheck)
    }

    function clearByRawIdentifier(rawId) {
        if (!rawId) return
        clearBadgeKeys([rawId])
    }

    function clearBadgeKeys(identifiers) {
        var targets = {}
        for (var i = 0; i < identifiers.length; i++) {
            if (!identifiers[i]) continue
            var raw = String(identifiers[i]).trim().toLowerCase()
            targets[raw] = true
            targets[raw.replace(/[^a-z0-9]/g, "")] = true
            targets[toCanonical(raw)] = true
        }
        var nextCounts = Object.assign({}, notificationCounts)
        var nextUrgent = Object.assign({}, canonicalUrgent)
        var nextTitles = Object.assign({}, titleExtractedBadges)
        var changed = false
        var sources = [nextCounts, nextUrgent, nextTitles]
        for (var s = 0; s < sources.length; s++) {
            for (var key in sources[s]) {
                var canonical = toCanonical(key)
                if (targets[key] || (canonical && targets[canonical])) {
                    delete sources[s][key]
                    changed = true
                }
            }
        }
        if (changed) {
            notificationCounts = nextCounts
            canonicalUrgent = nextUrgent
            titleExtractedBadges = nextTitles
            refreshCounts()
            scheduleSave()
        }
    }

    // -------------------------------------------------------------------------
    // 5. Channel 1: Omarchy Notification Service Listener (D-Bus)
    // -------------------------------------------------------------------------
    readonly property var notificationService: (shell && typeof shell.firstPartyServiceFor === "function")
        ? shell.firstPartyServiceFor("omarchy.notifications")
        : null

    readonly property var notifPopupModel: (notificationService && notificationService.popupModel) ? notificationService.popupModel : null
    readonly property int notifPopupCount: notifPopupModel ? notifPopupModel.count : 0

    // Snapshot of active popup app keys
    property var activePopupSnapshot: []

    function snapshotKey(item) {
        if (!item) return ""
        return item.app || item.appName || item.appIcon || ""
    }

    function rebuildSnapshot() {
        if (!notifPopupModel) { activePopupSnapshot = []; return }
        var snap = []
        for (var i = 0; i < notifPopupModel.count; i++) {
            try {
                var it = notifPopupModel.get(i)
                var k = snapshotKey(it)
                if (k) snap.push(k)
            } catch (e) {}
        }
        activePopupSnapshot = snap
    }

    function isAppCurrentlyActive(appKey) {
        if (!appKey) return false
        var targetCanonical = toCanonical(appKey)
        if (!targetCanonical) return false

        // Check ToplevelManager
        if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel) {
            var top = ToplevelManager.activeToplevel
            var topId = top.appId || top.title || ""
            if (toCanonical(topId) === targetCanonical) return true
        }

        // Check knownWindows
        if (tracker.knownWindows && tracker.knownWindows.length > 0) {
            for (var i = 0; i < tracker.knownWindows.length; i++) {
                var win = tracker.knownWindows[i]
                if (win && (win.active || win.activated)) {
                    var winId = win.appId || ""
                    if (toCanonical(winId) === targetCanonical) return true
                }
            }
        }
        return false
    }

    function processIncomingNotification(item) {
        if (!item) return
        var appKey = snapshotKey(item)
        if (!appKey) return
        var isCritical = (item.urgency === 2 || item.urgency === "critical")

        // If the application is already active and focused right now, do not show badge
        if (isAppCurrentlyActive(appKey)) {
            rebuildSnapshot()
            return
        }

        // 1. Primary app target
        tracker.incrementBadge(appKey, 1, isCritical)

        // Notification summaries are message content, never application identities.
        // Browser notifications retain the browser badge; PWAs use app metadata.

        rebuildSnapshot()
    }

    function processDisappeared() {
        rebuildSnapshot()
    }

    function hydrateActivePopups() {
        if (!notifPopupModel || notifPopupModel.count === 0) return
        for (var i = 0; i < notifPopupModel.count; i++) {
            try {
                var item = notifPopupModel.get(i)
                if (item) processIncomingNotification(item)
            } catch (e) {}
        }
        rebuildSnapshot()
    }

    onNotifPopupModelChanged: {
        if (notifPopupModel) {
            hydrateActivePopups()
        }
    }

    Component.onCompleted: {
        loadDiskState()
        Qt.callLater(function() {
            hydrateActivePopups()
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel) {
                var top = ToplevelManager.activeToplevel
                if (top.appId) tracker.clearByRawIdentifier(top.appId)
                if (top.title) tracker.clearByRawIdentifier(top.title)
            }
            tracker.syncWindowTitles()
            if (tracker.knownWindows) {
                for (var i = 0; i < tracker.knownWindows.length; i++) {
                    var w = tracker.knownWindows[i]
                    if (w && (w.active || w.activated)) {
                        if (w.appId) tracker.clearByRawIdentifier(w.appId)
                        if (w.title) tracker.clearByRawIdentifier(w.title)
                    }
                }
            }
        })
    }

    onNotifPopupCountChanged: {
        if (!notifPopupModel) return

        var prevCount = activePopupSnapshot.length
        var newCount = notifPopupModel.count

        if (newCount > prevCount) {
            // New notification arrived — increment badge
            try {
                var newest = notifPopupModel.get(0)
                if (newest) processIncomingNotification(newest)
            } catch (e) {}
        } else if (newCount < prevCount) {
            // Notification disappeared (auto-expire or click) — just sync snapshot
            processDisappeared()
        } else {
            // Same count but model changed (update/replace) — rebuild snapshot only
            rebuildSnapshot()
        }
    }

    // -------------------------------------------------------------------------
    // 6. Channel 2: Ghost Badge Cleanup Engine (Window Closed / Destroyed)
    // -------------------------------------------------------------------------
    property var previouslyOpenAppKeys: []

    function updateOpenWindowsAndClearClosed(currentWindows) {
        var currentAppKeys = []
        if (currentWindows && currentWindows.length > 0) {
            for (var i = 0; i < currentWindows.length; i++) {
                var win = currentWindows[i]
                if (!win) continue
                var appIdentifier = win.appId || ""
                var cKey = tracker.toCanonical(appIdentifier)
                if (cKey && currentAppKeys.indexOf(cKey) === -1) {
                    currentAppKeys.push(cKey)
                }
                var rawApp = String(win.appId || "").trim().toLowerCase()
                if (rawApp && currentAppKeys.indexOf(rawApp) === -1) {
                    currentAppKeys.push(rawApp)
                }

                // If this window is currently active, clear its badge immediately!
                if (win.active || win.activated) {
                    if (win.appId) tracker.clearByRawIdentifier(win.appId)
                    if (win.title) tracker.clearByRawIdentifier(win.title)
                }
            }
        }

        // 🌟 Feature 3: Auto-clear ghost badges when all windows of an application are closed
        if (tracker.previouslyOpenAppKeys && tracker.previouslyOpenAppKeys.length > 0) {
            for (var p = 0; p < tracker.previouslyOpenAppKeys.length; p++) {
                var closedAppKey = tracker.previouslyOpenAppKeys[p]
                if (closedAppKey && currentAppKeys.indexOf(closedAppKey) === -1) {
                    // All windows of this application were closed! Clear ghost badge.
                    tracker.clearByRawIdentifier(closedAppKey)
                }
            }
        }

        tracker.previouslyOpenAppKeys = currentAppKeys
        tracker.syncWindowTitles()
    }

    Connections {
        target: (typeof ToplevelManager !== "undefined") ? ToplevelManager : null
        function onActiveToplevelChanged() {
            if (ToplevelManager && ToplevelManager.activeToplevel) {
                var top = ToplevelManager.activeToplevel
                if (top.appId) tracker.clearByRawIdentifier(top.appId)
                if (top.title) tracker.clearByRawIdentifier(top.title)
            }
            tracker.syncWindowTitles()
        }
    }

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null

        function onRawEvent(event) {
            if (!event) return
            var evName = String(event.name || "")

            if (evName === "activewindow" || evName === "activewindowv2") {
                var wArgs = String(event.args || "")
                if (wArgs) {
                    var comma = wArgs.indexOf(",")
                    if (comma !== -1) {
                        var cls = wArgs.substring(0, comma).trim()
                        var ttl = wArgs.substring(comma + 1).trim()
                        if (cls) tracker.clearByRawIdentifier(cls)
                        if (ttl) tracker.clearByRawIdentifier(ttl)
                    } else {
                        tracker.clearByRawIdentifier(wArgs)
                        if (tracker.knownWindows) {
                            for (var kw = 0; kw < tracker.knownWindows.length; kw++) {
                                var win = tracker.knownWindows[kw]
                                if (win && (win.address === wArgs || String(win.address || "").indexOf(wArgs) !== -1)) {
                                    if (win.appId) tracker.clearByRawIdentifier(win.appId)
                                    if (win.title) tracker.clearByRawIdentifier(win.title)
                                    break
                                }
                            }
                        }
                    }
                }
                return
            }

            if (evName === "closewindow") {
                Qt.callLater(function() {
                    tracker.updateOpenWindowsAndClearClosed(tracker.knownWindows)
                })
                return
            }

            if (evName === "urgent") {
                var uAddr = String(event.args || "").trim()
                if (tracker.knownWindows) {
                    for (var u = 0; u < tracker.knownWindows.length; u++) {
                        var ut = tracker.knownWindows[u]
                        if (ut && (ut.address === uAddr || String(ut.address || "").indexOf(uAddr) !== -1)) {
                            var uApp = ut.appId || ""
                            if (uApp && !ut.active && !ut.activated) {
                                var cKey = tracker.toCanonical(uApp)
                                var lastTime = tracker.lastNotifTimestamps[cKey] || 0
                                // Deduplicate: If D-Bus notification arrived within last 1500ms, skip duplicate urgent trigger
                                if (Date.now() - lastTime > 1500) {
                                    tracker.incrementBadge(uApp, 1, true)
                                }
                            }
                            break
                        }
                    }
                }
                return
            }

            if (evName === "windowtitle" || evName === "windowtitlev2") {
                tracker.syncWindowTitles()
            }
        }
    }

    // -------------------------------------------------------------------------
    // 7. Channel 3: Live Window Title Badge Extractor (Web Apps & PWAs)
    // -------------------------------------------------------------------------
    property var titleExtractedBadges: ({})

    function extractUnreadFromTitle(title) {
        if (!title || typeof title !== "string") return 0
        // Matches (3), [5], (99+), etc. with sane bound <= 999 to avoid process IDs or ports
        var m = title.match(/(?:\(|\[)(\d{1,3})(?:\+)?(?:\)|\])/)
        if (m && m[1]) {
            var val = parseInt(m[1], 10)
            return (!isNaN(val) && val > 0 && val <= 999) ? val : 0
        }
        return 0
    }

    function syncWindowTitles() {
        var nextTitleBadges = {}
        var windows = tracker.knownWindows || []
        for (var i = 0; i < windows.length; i++) {
            var win = windows[i]
            if (!win) continue
            var ttl = String(win.title || "").trim()
            if (!ttl) continue
            var unread = extractUnreadFromTitle(ttl)
            var appIdentifier = win.appId || ""
            var cKey = tracker.toCanonical(appIdentifier)
            if (cKey && unread > 0 && !tracker.isAppCurrentlyActive(appIdentifier)) {
                nextTitleBadges[cKey] = Math.max(nextTitleBadges[cKey] || 0, unread)
            }
        }
        if (JSON.stringify(nextTitleBadges) !== JSON.stringify(tracker.titleExtractedBadges)) {
            tracker.titleExtractedBadges = nextTitleBadges
            tracker.refreshCounts()
        }
    }

    onKnownWindowsChanged: {
        updateOpenWindowsAndClearClosed(tracker.knownWindows)
    }
}
