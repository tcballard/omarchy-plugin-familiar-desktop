// Grouping and badge identity only. Never use these keys to launch an app.
.pragma library

function toCanonical(str) {
    if (!str || typeof str !== "string") return ""
    var raw = str.trim().toLowerCase()
    if (!raw) return ""

    // 1. First-class desktop & Web App service aliases (checked on raw string)
    if (raw.indexOf("transmission") !== -1) return "transmission"
    if (raw.indexOf("yandex-browser") !== -1 || (raw.indexOf("yandex") !== -1 && raw.indexOf("mail") === -1 && raw.indexOf("music") === -1)) return "yandex-browser"
    if (raw.indexOf("telegram") !== -1) return "telegram"
    if (raw.indexOf("whatsapp") !== -1) return "whatsapp"
    if (raw.indexOf("chatgpt") !== -1 || raw.indexOf("openai") !== -1) return "chatgpt"
    if (raw.indexOf("claude") !== -1 || raw.indexOf("anthropic") !== -1) return "claude"
    if (raw.indexOf("gemini") !== -1) return "gemini"
    if (raw.indexOf("notion") !== -1) return "notion"
    if (raw.indexOf("figma") !== -1) return "figma"
    if (raw.indexOf("github") !== -1) return "github"
    if (raw.indexOf("gitlab") !== -1) return "gitlab"
    if (raw.indexOf("linear") !== -1) return "linear"
    if (raw.indexOf("trello") !== -1) return "trello"
    if (raw.indexOf("jira") !== -1) return "jira"
    if (raw.indexOf("slack") !== -1) return "slack"
    if (raw.indexOf("discord") !== -1 || raw.indexOf("vesktop") !== -1 || raw.indexOf("webcord") !== -1) return "discord"
    if (raw.indexOf("spotify") !== -1) return "spotify"
    if (raw.indexOf("gmail") !== -1 || raw.indexOf("mail.google.com") !== -1) return "gmail"
    if (raw.indexOf("outlook") !== -1) return "outlook"
    if (raw.indexOf("proton") !== -1 || raw.indexOf("protonmail") !== -1) return "protonmail"
    if (raw.indexOf("antigravity") !== -1) return "antigravity"
    if (raw.indexOf("code") !== -1 || raw.indexOf("vscodium") !== -1 || raw.indexOf("vscode") !== -1) return "code"
    if (raw.indexOf("nautilus") !== -1 || raw.indexOf("org.gnome.nautilus") !== -1 || raw.indexOf("thunar") !== -1 || raw.indexOf("dolphin") !== -1) return "nautilus"
    if (raw.indexOf("kitty") !== -1 || raw.indexOf("alacritty") !== -1 || raw.indexOf("ghostty") !== -1 || raw.indexOf("foot") !== -1 || raw.indexOf("terminal") !== -1) return "terminal"
    // Chromium web apps ("chrome-youtube.com__-Default") must keep their own site
    // as the key. Folding them all into "chrome" made a number in ONE app's title
    // (YouTube's "(13) ...") show as a badge on EVERY web app (Maps too).
    var webApp = raw.match(/^chrome-([a-z0-9.-]+?)__/)
    if (webApp) {
        var labels = webApp[1].replace(/^(www|web|app|m)\./, "").split(".")
        if (labels[0]) return labels[0]
    }
    if (raw.indexOf("chrome") !== -1 || raw.indexOf("chromium") !== -1) return "chrome"
    if (raw.indexOf("firefox") !== -1 || raw.indexOf("zen-browser") !== -1) return "firefox"

    // 2. Extract domain core from Web App URLs (e.g. https://web.whatsapp.com -> whatsapp, https://photos.google.com -> photos)
    var urlMatch = raw.match(/https?:\/\/(?:www\.|web\.|app\.|mail\.)?([a-zA-Z0-9-]+)\./i)
    if (urlMatch && urlMatch[1]) {
        var dom = urlMatch[1].toLowerCase()
        var ignoredProviders = ["com", "org", "net", "io", "app", "dev", "google", "yandex", "microsoft", "apple"]
        if (ignoredProviders.indexOf(dom) === -1) {
            return dom
        } else {
            // If subdomain is provider itself (e.g. google.com/photos), extract path token
            var pathMatch = raw.match(/https?:\/\/[^\/]+\/([a-zA-Z0-9-]+)/i)
            if (pathMatch && pathMatch[1] && pathMatch[1].length >= 3) {
                return pathMatch[1].toLowerCase()
            }
        }
    }

    // 3. Generic stripping
    var s = raw
    s = s.replace(/\.desktop$/i, "")
    s = s.replace(/\.appimage$/i, "")
    s = s.replace(/-(?:bin|git|stable|nightly|electron|desktop)$/i, "")
    s = s.replace(/^(?:org|com|io|net|edu|dev)\.[a-z0-9_]+\./i, "")
    s = s.replace(/^(?:org|com|io|net|edu|dev)\./i, "")
    return s.replace(/[^a-z0-9]/g, "")
}
