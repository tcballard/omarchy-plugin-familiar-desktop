import QtQuick
import qs.Commons
import ".."

Rectangle {
    id: picker
    required property var folder
    required property var icons
    property bool vertical: false
    property bool transparent: false
    property real rounding: 10
    property var borderSpec: null
    property Component borderOverlay: null
    property int selectedIndex: -1
    property bool keyboardNavigation: false
    readonly property int optionCount: folder ? icons.length + 1 : 0

    signal iconChosen(string icon)
    signal dissolveRequested()
    signal dismissRequested()
    signal hoverChanged(bool hovered)

    function resetSelection() {
        var index = folder ? icons.indexOf(folder.icon) : -1
        selectedIndex = index >= 0 ? index : 0
    }
    function navigate(step) {
        keyboardNavigation = true
        if (optionCount > 0) selectedIndex = (selectedIndex + step + optionCount) % optionCount
    }
    function wheel(delta) { navigate(delta > 0 ? -1 : 1) }
    function activateSelection() {
        if (!folder) return
        if (selectedIndex >= 0 && selectedIndex < icons.length) {
            var icon = icons[selectedIndex]
            iconChosen(folder.icon === icon ? "grid" : icon)
        } else if (selectedIndex === icons.length) {
            dissolveRequested()
        }
        dismissRequested()
    }

    width: vertical ? 36 : Math.max(36, (icons.length + 1) * 30 + 10)
    height: vertical ? Math.max(36, (icons.length + 1) * 30 + 10) : 36
    focus: true
    color: transparent ? Util.alpha(Color.popups.background, 0.45) : Color.popups.background
    border.width: Border.canUseNative(borderSpec) && !transparent ? Border.uniformWidth(borderSpec) : 0
    border.color: Border.canUseNative(borderSpec) && !transparent ? Border.color(borderSpec) : "transparent"
    radius: Math.min(10, rounding)
    antialiasing: true
    smooth: true

    HoverHandler { onHoveredChanged: picker.hoverChanged(hovered) }
    Keys.onLeftPressed: event => { event.accepted = true; picker.navigate(-1) }
    Keys.onUpPressed: event => { event.accepted = true; picker.navigate(-1) }
    Keys.onRightPressed: event => { event.accepted = true; picker.navigate(1) }
    Keys.onDownPressed: event => { event.accepted = true; picker.navigate(1) }
    Keys.onReturnPressed: event => { event.accepted = true; picker.activateSelection() }
    Keys.onEnterPressed: event => { event.accepted = true; picker.activateSelection() }
    Keys.onSpacePressed: event => { event.accepted = true; picker.activateSelection() }
    Keys.onEscapePressed: event => { event.accepted = true; picker.dismissRequested() }

    Loader {
        anchors.fill: parent
        active: !picker.transparent && Border.needsOverlay(picker.borderSpec)
        sourceComponent: picker.borderOverlay
    }
    Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
    Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
    Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: picker.keyboardNavigation ? Qt.BlankCursor : Qt.ArrowCursor
        onPositionChanged: picker.keyboardNavigation = false
        onWheel: wheel => picker.wheel(wheel.angleDelta.y || wheel.angleDelta.x)
    }

    component Choice: Item {
        id: choice
        required property int optionIndex
        required property string glyph
        property bool dissolve: false
        readonly property bool current: !dissolve && !!picker.folder && picker.folder.icon === glyph
        readonly property bool selected: picker.selectedIndex === optionIndex
        width: picker.vertical ? 24 : 26
        height: picker.vertical ? 26 : 24
        objectName: dissolve ? "dissolve-folder" : "folder-icon-" + optionIndex

        DockGlyph {
            anchors.fill: parent
            text: choice.glyph
            fontFamily: Style.font.family
            fontSize: choice.dissolve ? 16 : 14
            color: choice.current || choice.selected ? Color.accent : Color.popups.text
            scale: choice.selected ? 1.25 : 1
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: choice.current ? Color.composed("accent", "accent-alpha", Color.accent, 0.22) : "transparent"
            border.width: choice.current ? 1 : 0
            border.color: choice.current ? Color.accent : "transparent"
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: picker.keyboardNavigation ? Qt.BlankCursor : Qt.PointingHandCursor
            onEntered: if (!picker.keyboardNavigation) picker.selectedIndex = choice.optionIndex
            onPositionChanged: {
                picker.keyboardNavigation = false
                picker.selectedIndex = choice.optionIndex
            }
            onWheel: wheel => picker.wheel(wheel.angleDelta.y || wheel.angleDelta.x)
            onClicked: {
                picker.selectedIndex = choice.optionIndex
                picker.activateSelection()
            }
        }
    }

    Grid {
        anchors.centerIn: parent
        columns: picker.vertical ? 1 : picker.icons.length + 2
        spacing: 4
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        Repeater {
            model: picker.folder ? picker.icons : []
            Choice {
                required property int index
                required property string modelData
                optionIndex: index
                glyph: modelData
            }
        }
        Rectangle {
            width: picker.vertical ? 14 : 1
            height: picker.vertical ? 1 : 14
            color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.35)
        }
        Choice { optionIndex: picker.icons.length; glyph: "-"; dissolve: true }
    }
}
