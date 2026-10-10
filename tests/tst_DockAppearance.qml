import QtQuick
import QtTest
import qs.Commons
import qs.Commons as Commons
import "../components"

TestCase {
    name: "DockAppearance"
    QtObject { id: hypr; signal rawEvent(var event) }
    DockAppearance { id: appearance; hyprland: hypr }
    function init() {
        appearance.backgroundOpacity = "theme"
        appearance.barTransparent = false
        appearance.systemBorderSize = 2
        appearance.systemRounding = 12
        appearance.hyprlandActiveBorderRaw = ""
        for (var name of ["rounding", "border-size", "active-border", "animations"])
            findChild(appearance, "appearance-" + name).running = false
    }
    function test_gradientAndBackgroundOpacity() {
        var gradient = appearance.parseHyprlandGradient("0x80ff0000 #00ff00 30deg", "#000000")
        compare(gradient.angle, 30)
        compare(gradient.colors.length, 2)
        verify(gradient.enabled)
        compare(gradient.colors[0], Qt.rgba(1, 0, 0, 128 / 255))
        appearance.backgroundOpacity = "100"
        appearance.systemBorderSize = 3
        findChild(appearance, "appearance-active-border").complete('{"gradient":"0xff112233 0xff445566 45deg"}', 0)
        compare(appearance.dockBorderSpec.widths.top, 3)
        compare(appearance.dockBorderSpec.gradient.angle, 45)
        appearance.backgroundOpacity = "50"
        verify(appearance.backgroundTransparent)
        fuzzyCompare(appearance.backgroundColor.a, 0.5, 0.001)
        compare(appearance.dockBorderSpec.widths.top, 0)
        appearance.backgroundOpacity = "theme"
        appearance.barTransparent = true
        fuzzyCompare(appearance.backgroundColor.a, 0.25, 0.001)
    }
    function test_queriesAndInvalidResponses() {
        var rounding = findChild(appearance, "appearance-rounding")
        var border = findChild(appearance, "appearance-border-size")
        rounding.complete('{"int":18}', 0)
        border.complete('{"int":4}', 0)
        compare(appearance.systemRounding, 18)
        compare(appearance.systemBorderSize, 4)
        rounding.complete('invalid json', 0)
        border.complete('{"int":-1}', 0)
        compare(appearance.systemRounding, 18)
        compare(appearance.systemBorderSize, 4)
        findChild(appearance, "appearance-animations").complete('name: borderangle\nenabled: 0\nspeed: 20', 0)
        compare(appearance.borderAngleAnimationEnabled, false)
        compare(appearance.borderAngleAnimationDuration, 4000)
    }
    function test_backgroundMatrixPreservesTheTheme() {
        var original = Commons.Color.bar.background
        try {
            for (var transparent of [true, false]) {
                appearance.barTransparent = transparent
                for (var background of [Qt.rgba(.1, .2, .3, 1), Qt.rgba(.7, .6, .5, 0)]) {
                    Commons.Color.bar.background = background
                    for (var choice of ["theme", "0", "25", "50", "75", "100"]) {
                        appearance.backgroundOpacity = choice
                        fuzzyCompare(appearance.backgroundColor.a, choice === "theme" ? (transparent ? .25 : background.a) : Number(choice) / 100, .001)
                        fuzzyCompare(appearance.backgroundColor.r, background.r, .001)
                        fuzzyCompare(appearance.backgroundColor.g, background.g, .001)
                        fuzzyCompare(appearance.backgroundColor.b, background.b, .001)
                        compare(appearance.backgroundTransparent, choice === "theme" ? transparent : Number(choice) < 100)
                        compare(Commons.Color.bar.background, background, "the theme stays untouched")
                    }
                }
            }
        } finally { Commons.Color.bar.background = original }
    }
    function test_refreshCoalescesWhileQueriesAreRunning() {
        var rounding = findChild(appearance, "appearance-rounding")
        var before = rounding.starts
        appearance.refresh()
        hypr.rawEvent({name: "configreloaded"})
        tryCompare(rounding, "starts", before + 1, 500)
        verify(rounding.running)
        appearance.refresh()
        wait(200)
        compare(rounding.starts, before + 1)
    }
}
