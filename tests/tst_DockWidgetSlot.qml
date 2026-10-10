import QtQuick
import QtTest
import "../components"

TestCase {
    name: "DockWidgetSlot"
    visible: true
    when: windowShown
    QtObject {
        id: hostActions
        property int attachments: 0
        property var lastAnchor: null
        function componentFor(id) { return widget }
        function sourceFor(id) { return "" }
        function attach(item, id, anchor) { attachments++; lastAnchor = anchor }
        function iconFor(id, item) { return item ? item.icon : "" }
        function activate(id, item, anchor, mouse) { lastAnchor = anchor }
    }
    Component { id: widget; Item { property string icon: "A"; property string displayText: "Clock text" } }
    Component {
        id: factory
        DockWidgetSlot {
            actions: hostActions; offset: 120
            isVertical: false; clockSlotWidth: 140; slotSize: 42; iconBaseSize: 24
            isEditMode: false; clockDisplayText: ""; currentHourString: "10"; currentMinutePart: "30"
            widgetIconRevision: 0; widgetRegistryRevision: 0
            pipewireSinkVolume: 0; pipewireSinkMuted: false; pipewireSourceMuted: false
            upowerBatteryPercentage: 0; upowerBatteryState: 0
        }
    }
    function test_geometryAndRegistryRefreshPreserveTheHostedInstance() {
        var slot = createTemporaryObject(factory, this, {modelData: "omarchy.agents", index: 0})
        wait(0)
        compare(slot.x, 120); compare(slot.y, 0)
        compare(slot.width, 42); compare(slot.height, 42)
        var loader = findChild(slot, "hosted-widget-loader")
        verify(loader.item !== null)
        compare(hostActions.lastAnchor, slot)
        var hosted = loader.item
        var count = hostActions.attachments
        slot.widgetRegistryRevision++
        wait(0)
        compare(loader.item, hosted)
        compare(hostActions.attachments, count)
        slot.isVertical = true
        compare(slot.x, 0); compare(slot.y, 120)
        slot.modelData = "omarchy.clock"
        compare(slot.width, 42); compare(slot.height, 42)
        slot.isVertical = false
        compare(slot.width, 140); compare(slot.height, 42)
    }
    Component {
        id: repeatedFactory
        Item { Repeater { objectName: "slots"; model: ["omarchy.agents", "omarchy.clock"]; delegate: factory } }
    }

    Component { id: iconFactory; AppIcon { width: 32; height: 32 } }
    function test_panelGlyphUsesTheWidgetFontAndSkipsImageLookup() {
        var icon = createTemporaryObject(iconFactory, this, {glyph: "\uf09e", source: "file:///unneeded-qt-icon.png"})
        var glyph = findChild(icon, "app-icon-glyph")
        var image = findChild(icon, "app-icon-image")
        compare(glyph.text, "\uf09e")
        compare(glyph.visible, true)
        compare(glyph.fontSize, 32)
        compare(image.visible, false)
        compare(String(image.source), "")
        icon.color = "#ff8844"
        compare(glyph.color, icon.color)
        icon.source = ""
        icon.glyph = ""
        compare(glyph.visible, false)
        compare(image.visible, true)
        icon.source = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        tryCompare(image, "status", Image.Ready)
        verify(image.sourceSize.width >= 128)
    }
    function test_repeaterSuppliesInheritedRequiredProperties() {
        var group = createTemporaryObject(repeatedFactory, this)
        wait(0)
        var repeater = findChild(group, "slots")
        compare(repeater.count, 2)
        compare(repeater.itemAt(0).modelData, "omarchy.agents")
        compare(repeater.itemAt(0).index, 0)
        compare(repeater.itemAt(1).modelData, "omarchy.clock")
        compare(repeater.itemAt(1).index, 1)
        compare(repeater.itemAt(1).width, 140)
    }

}
