import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Owns compositor/theme appearance observations, independently of dock windows.
Item {
    id: appearance
    property var hyprland: null
    property string backgroundOpacity: "theme"
    property bool barTransparent: false
    readonly property color backgroundColor: backgroundOpacity === "theme"
        ? (barTransparent ? Util.alpha(Color.bar.background, 0.25) : Color.bar.background)
        : Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, Number(backgroundOpacity) / 100)
    readonly property bool backgroundTransparent: backgroundOpacity === "theme"
        ? barTransparent : Number(backgroundOpacity) < 100

    // Dynamic system tiling border size, rounding & active gradient border
    property int systemBorderSize: 2
    property int systemRounding: Style.cornerRadius >= 0 ? Style.cornerRadius : 12
    property string hyprlandActiveBorderRaw: ""

    function parseHyprlandColor(str) {
        var s = String(str || "").trim()
        var m8 = s.match(/^(?:0x|#|rgba\()?([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\)?$/)
        if (m8) {
            var a = parseInt(m8[1], 16) / 255
            var r = parseInt(m8[2], 16)
            var g = parseInt(m8[3], 16)
            var b = parseInt(m8[4], 16)
            return Qt.rgba(r / 255, g / 255, b / 255, a)
        }
        var m6 = s.match(/^(?:0x|#|rgb\()?([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\)?$/)
        if (m6) {
            var r = parseInt(m6[1], 16)
            var g = parseInt(m6[2], 16)
            var b = parseInt(m6[3], 16)
            return Qt.rgba(r / 255, g / 255, b / 255, 1.0)
        }
        return s
    }

    function parseHyprlandGradient(raw, fallbackColor) {
        var s = String(raw || "").trim()
        if (!s) return { colors: [fallbackColor], angle: 0, enabled: false }
        var parts = s.split(/\s+/)
        var colors = []
        var angle = 0
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i]
            if (p.match(/^-?\d+(?:\.\d+)?deg$/)) {
                angle = Number(p.replace(/deg$/, ""))
            } else {
                var c = appearance.parseHyprlandColor(p)
                if (c) colors.push(c)
            }
        }
        if (colors.length === 0) colors.push(fallbackColor)
        return {
            colors: colors,
            angle: angle,
            enabled: colors.length > 1
        }
    }

    property var dockBorderSpec: {
        if (appearance.backgroundTransparent || appearance.systemBorderSize <= 0) {
            return Border.none()
        }
        var raw = appearance.hyprlandActiveBorderRaw
        if (raw && raw.length > 0) {
            var grad = appearance.parseHyprlandGradient(raw, Color.accent)
            return {
                color: grad.colors[0],
                widths: { top: appearance.systemBorderSize, right: appearance.systemBorderSize, bottom: appearance.systemBorderSize, left: appearance.systemBorderSize },
                gradient: grad
            }
        }
        return Border.hyprlandActiveSpec(Color.accent, appearance.systemBorderSize)
    }

    Process {
        id: roundingProc
        objectName: "appearance-rounding"
        command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var json = JSON.parse(text || "{}")
                    var n = Number(json.int)
                    if (isFinite(n) && n >= 0) {
                        if (appearance.systemRounding !== n) {
                            appearance.systemRounding = n
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: borderSizeProc
        objectName: "appearance-border-size"
        command: ["hyprctl", "-j", "getoption", "general:border_size"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var json = JSON.parse(text || "{}")
                    var n = Number(json.int)
                    if (isFinite(n) && n >= 0) {
                        if (appearance.systemBorderSize !== n) {
                            appearance.systemBorderSize = n
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: activeBorderProc
        objectName: "appearance-active-border"
        command: ["hyprctl", "-j", "getoption", "general:col.active_border"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var json = JSON.parse(text || "{}")
                    var grad = String(json.gradient || json.str || "").trim()
                    if (grad.length > 0) {
                        if (appearance.hyprlandActiveBorderRaw !== grad) {
                            appearance.hyprlandActiveBorderRaw = grad
                        }
                    }
                } catch(e) {}
            }
        }
    }

    property bool borderAngleAnimationEnabled: true
    property real borderAngleAnimationDuration: 6000

    Process {
        id: animationsProc
        objectName: "appearance-animations"
        command: ["hyprctl", "animations"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var str = text || ""
                    var match = str.match(/name:\s*borderangle[\s\S]*?enabled:\s*([0-9-]+)[\s\S]*?speed:\s*([0-9.]+)/)
                    if (match) {
                        var en = Number(match[1])
                        var sp = Number(match[2])
                        appearance.borderAngleAnimationEnabled = (en === 1)
                        if (isFinite(sp) && sp > 0) {
                            appearance.borderAngleAnimationDuration = Math.max(1000, sp * 200)
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: hyprlandRefreshDebounceTimer
        interval: 150
        repeat: false
        onTriggered: appearance.doRefresh()
    }

    function refresh() {
        hyprlandRefreshDebounceTimer.restart()
    }

    function doRefresh() {
        if (!roundingProc.running) roundingProc.running = true
        if (!borderSizeProc.running) borderSizeProc.running = true
        if (!activeBorderProc.running) activeBorderProc.running = true
        if (!animationsProc.running) animationsProc.running = true
    }

    Connections {
        target: appearance.hyprland
        function onRawEvent(event) {
            if (event && event.name === "configreloaded") {
                appearance.refresh()
            }
        }
    }

    Connections {
        target: Style
        function onCornerRadiusChanged() {
            if (Style.cornerRadius >= 0) appearance.systemRounding = Style.cornerRadius
        }
        function onNormalBorderWidthChanged() {
            if (Style.normalBorderWidth >= 0) appearance.systemBorderSize = Style.normalBorderWidth
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/looknfeel.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: appearance.refresh()
        onLoaded: appearance.refresh()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: appearance.refresh()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr/window-no-gaps.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: appearance.refresh()
    }

}
