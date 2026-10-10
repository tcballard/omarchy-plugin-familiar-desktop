import QtQuick
import qs.Commons as Commons

QtObject {
    Component.onCompleted: {
        var colours = [Commons.Color.accent, Commons.Color.popups.text,
                       Commons.Color.popups.background, Commons.Color.popups.border,
                       Commons.Color.bar.text, Commons.Color.bar.background]
        for (var i = 0; i < colours.length; ++i) {
            if (!colours[i] || !isFinite(colours[i].r) || !isFinite(colours[i].a)) {
                console.error("Palette did not resolve", i)
                Qt.exit(1)
                return
            }
        }
        console.log("PASS: qualified Commons palette resolves on the native runtime")
        Qt.quit()
    }
}
