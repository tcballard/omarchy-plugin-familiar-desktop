.pragma library

// Chords come from the running compositor, never from this catalogue.
var lessons = [
    {id: "maximizeWindow", title: "Maximise window", hintTitle: "Window size changed",
        description: "With the window focused, change its size without reaching for the mouse.",
        bindingDescription: "Full width", dispatcher: "fullscreen", argument: "1", maxHints: 3},
    {id: "closeWindow", title: "Close window", hintTitle: "Close requested",
        description: "Close the focused window without reaching for the mouse.",
        bindingDescription: "Close window", dispatcher: "killactive", argument: "", maxHints: 3},
    {id: "toggleFloating", title: "Floating and tiling", hintTitle: "Window layout changed",
        description: "Switch the focused window between floating and tiling with one shortcut.",
        bindingDescription: "Toggle window floating/tiling", dispatcher: "togglefloating", argument: "", maxHints: 3}
]

var lessonCooldown = 24 * 60 * 60 * 1000
var globalCooldown = 2 * 60 * 1000

function object(value) {
    return value && typeof value === "object" && !Array.isArray(value)
}

function count(value) {
    return typeof value === "number" && isFinite(value) && value >= 0
        ? Math.min(Math.floor(value), Number.MAX_SAFE_INTEGER) : 0
}

function lessonState(value) {
    var s = object(value) ? value : {}
    return {hintsShown: count(s.hintsShown), learned: s.learned === true,
        skipped: s.skipped === true, lastShownAt: count(s.lastShownAt)}
}

function normalize(value) {
    var raw = object(value) ? value : {}
    // Preserve progress for lessons temporarily unavailable or added by a later build.
    var progress = {}
    var entries = object(raw.lessons) ? raw.lessons : {}
    Object.keys(entries).slice(0, 200).forEach(function(id) {
        if (/^[a-zA-Z][a-zA-Z0-9]{0,63}$/.test(id)) progress[id] = lessonState(entries[id])
    })
    return {schemaVersion: 1, enabled: raw.enabled !== false,
        lastHintAt: count(raw.lastHintAt), lessons: progress}
}

function parse(text) {
    try {
        var raw = JSON.parse(text || "{}")
        if (object(raw) && raw.schemaVersion !== undefined && raw.schemaVersion !== 1)
            return {state: normalize({enabled: false}), writable: false,
                message: "This learning file needs a newer Familiar build."}
        return {state: normalize(raw), writable: true, message: ""}
    } catch (e) {
        return {state: normalize({}), writable: true,
            message: "Learning progress could not be read. Starting with empty progress."}
    }
}

function find(id) {
    for (var i = 0; i < lessons.length; i++) if (lessons[i].id === id) return lessons[i]
    return null
}

// Lua dispatchers are opaque in hyprctl binds. Use only Omarchy's exact semantic
// descriptions, checked against default/hypr/bindings/tiling.lua. Legacy binds
// must also match their actual dispatcher/argument. Custom mislabelled Lua is
// not introspectable; we never execute it or guess from keys/app names.
function matches(lesson, binding) {
    if (!binding || binding.description !== lesson.bindingDescription) return false
    if (binding.dispatcher === "__lua") return true
    return binding.dispatcher === lesson.dispatcher && String(binding.arg || "").trim() === lesson.argument
}

function catalogue(bindings) {
    if (!Array.isArray(bindings)) return []
    bindings = bindings.filter(function(binding) { return object(binding) })
    return lessons.reduce(function(result, lesson) {
        var binding = bindings.find(function(b) {
            if (!matches(lesson, b) || b.submap || b.mouse || b.release || b.longPress || b.catch_all) return false
            if (typeof b.keys !== "string" || typeof b.key !== "string" || !b.keys.trim() || !b.key.trim()
                || /^(mouse|switch):|^mouse_|^code:/.test(b.key)) return false
            // A second action on the same chord is not a reliable equivalent.
            return bindings.filter(function(other) {
                return !other.submap && String(other.keys).toLowerCase() === b.keys.toLowerCase()
            }).length === 1
        })
        if (binding) result.push({id: lesson.id, title: lesson.title, hintTitle: lesson.hintTitle,
            description: lesson.description, shortcut: binding.keys, maxHints: lesson.maxHints})
        return result
    }, [])
}

function eligible(lesson, state, now) {
    if (!lesson || !state.enabled || !isFinite(now) || now < 0) return false
    var s = lessonState(state.lessons[lesson.id])
    if (s.learned || s.skipped || s.hintsShown >= lesson.maxHints) return false
    // A clock moving backwards suppresses hints until it catches up.
    return (!s.hintsShown || now - s.lastShownAt >= lessonCooldown)
        && (!state.lastHintAt || now - state.lastHintAt >= globalCooldown)
}

function shown(state, id, now) {
    var next = normalize(state)
    var s = lessonState(next.lessons[id])
    s.hintsShown++
    s.lastShownAt = now
    next.lastHintAt = now
    next.lessons[id] = s
    return next
}

function learned(state, id) {
    var next = normalize(state)
    if (!find(id)) return next
    var s = lessonState(next.lessons[id])
    s.learned = true
    next.lessons[id] = s
    return next
}

function progress(catalogue, state) {
    var enabled = catalogue.filter(function(lesson) { return !lessonState(state.lessons[lesson.id]).skipped })
    var learned = enabled.filter(function(lesson) { return lessonState(state.lessons[lesson.id]).learned }).length
    return {learned: learned, total: enabled.length, fraction: enabled.length ? learned / enabled.length : 0}
}

function actionLesson(result) {
    if (!result || result.state !== "ok") return ""
    if (result.action === "arrange-maximize") return result.wasMaximized ? "" : "maximizeWindow"
    // Familiar's float/tile actions also clear fullscreen; a simple toggle
    // cannot teach that extra operation, or an action that changed nothing.
    if (result.wasFullscreen) return ""
    if (result.action === "arrange-float" && result.wasFloating === false) return "toggleFloating"
    if (result.action === "arrange-tile" && result.wasFloating === true) return "toggleFloating"
    return ""
}
