import QtQuick
import QtTest
import "../DockWidgets.js" as DockWidgets

TestCase {
    name: "DockWidgets"

    function test_addWidgetToDockList() {
        var list = DockWidgets.addWidgetToDockList([], "silvaio.gamemode");
        compare(list, ["silvaio.gamemode"]);

        var withApps = DockWidgets.addWidgetToDockList(list, "omarchy.apps");
        compare(withApps, ["omarchy.apps", "silvaio.gamemode"]);

        var replaced = DockWidgets.addWidgetToDockList(withApps, "lgse.sandman");
        compare(replaced, ["omarchy.apps", "lgse.sandman"]);

        var removed = DockWidgets.removeWidgetFromDockList(replaced, "lgse.sandman");
        compare(removed, ["omarchy.apps"]);
    }

    function test_getDockWidgetLayout() {
        var layout = DockWidgets.getDockWidgetLayout(true, "left", true, ["omarchy.apps", "silvaio.gamemode"], "right");
        compare(layout.leftWidgets, ["omarchy.apps"]);
        compare(layout.rightWidgets, ["silvaio.gamemode"]);
    }
}
