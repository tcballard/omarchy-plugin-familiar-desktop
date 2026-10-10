import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."
import "../DockModel.js" as DockModel

PanelWindow {
    id: pickerWindow

    property var root: null
    property var dockWindow: null
    property var shell: null
    property bool opened: false

    onOpenedChanged: {
        if (pickerWindow.root && typeof pickerWindow.root.handleWidgetPickerOpenedChanged === "function") {
            pickerWindow.root.handleWidgetPickerOpenedChanged(opened)
        }
    }

    WlrLayershell.namespace: "omarchy-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pickerWindow.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    screen: (pickerWindow.dockWindow && pickerWindow.dockWindow.screen) ? pickerWindow.dockWindow.screen : (Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    visible: opened && pickerWindow.root && pickerWindow.root.dockRevealed

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Fullscreen Screen Dimming / Blur Scrim (Matches Omarchy Menu)
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Commons.Color.menu.scrim
        opacity: pickerWindow.opened ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // Outside click dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            pickerWindow.opened = false
        }
    }

    // Centered Picker Card (Exact Omarchy Menu border & theme styling)
    BorderSurface {
        id: pickerCard
        width: 380
        height: 540
        anchors.centerIn: parent

        color: Commons.Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius >= 0 ? Style.cornerRadius : 14
        antialiasing: true
        smooth: true

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        focus: pickerWindow.opened
        Keys.onEscapePressed: function(event) {
            pickerWindow.opened = false
            event.accepted = true
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // 1. Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Dock Widgets"
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: 14
                    font.bold: true
                    color: Commons.Color.menu.text
                    Layout.fillWidth: true
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Commons.Color.composed("menu.border", "menu.border-alpha", Commons.Color.border, 0.25)
            }

            // 2. App Menu Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // App Menu Position Control
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 7
                    color: Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.05)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        spacing: 8

                        Text {
                            text: "App Menu position:"
                            textFormat: Text.PlainText
                            font.family: Style.font.family
                            font.pixelSize: 11
                            font.bold: true
                            color: Commons.Color.menu.text
                            Layout.fillWidth: true
                        }

                        // Segmented Button: Left | Right
                        Row {
                            spacing: 3

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isLeft: (!pickerWindow.root || pickerWindow.root.appMenuPosition !== "right")
                                color: isLeft ? Commons.Color.accent : (posAppLeftMouse.containsMouse ? Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Left"
                                    textFormat: Text.PlainText
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isLeft ? Commons.Color.background : Commons.Color.menu.text
                                }

                                MouseArea {
                                    id: posAppLeftMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("left")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("left")
                                    }
                                }
                            }

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isRight: (pickerWindow.root && pickerWindow.root.appMenuPosition === "right")
                                color: isRight ? Commons.Color.accent : (posAppRightMouse.containsMouse ? Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Right"
                                    textFormat: Text.PlainText
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isRight ? Commons.Color.background : Commons.Color.menu.text
                                }

                                MouseArea {
                                    id: posAppRightMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("right")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("right")
                                    }
                                }
                            }
                        }
                    }
                }

                // App Menu Item Toggle
                Rectangle {
                    id: appMenuItemRow
                    Layout.fillWidth: true
                    height: 38
                    radius: 7

                    readonly property bool isInDock: !!(pickerWindow.root && pickerWindow.root.dockWidgets && pickerWindow.root.dockWidgets.indexOf("omarchy.apps") !== -1)
                    readonly property bool isHovered: appItemMouse.containsMouse

                    color: isInDock ? Commons.Color.composed("menu.selectedBackground", "menu.selectedBackground-alpha", Commons.Color.accent, isHovered ? 0.18 : 0.10) : (isHovered ? Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.06) : "transparent")
                    border.width: 1
                    border.color: isInDock ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.4) : (isHovered ? Commons.Color.composed("menu.border", "menu.border-alpha", Commons.Color.border, 0.2) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Icon
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 5
                            color: appMenuItemRow.isInDock ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.2) : Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.08)

                            DockGlyph {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                text: "󰀻"
                                fontFamily: Style.font.family
                                fontSize: 14
                                color: appMenuItemRow.isInDock ? Commons.Color.accent : Commons.Color.menu.text
                            }
                        }

                        // Title & Badge
                        Row {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            spacing: 8

                            Text {
                                text: "Apps"
                                textFormat: Text.PlainText
                                font.family: Style.font.family
                                font.pixelSize: 12
                                font.bold: true
                                color: Commons.Color.menu.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                height: 16
                                width: appBadgeText.implicitWidth + 8
                                radius: 4
                                color: appMenuItemRow.isInDock ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.25) : Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.08)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: appBadgeText
                                    anchors.centerIn: parent
                                    text: appMenuItemRow.isInDock ? "Dock" : "Off"
                                    textFormat: Text.PlainText
                                    font.family: Style.font.family
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: appMenuItemRow.isInDock ? Commons.Color.accent : Commons.Color.muted
                                }
                            }
                        }

                        // Toggle Switch
                        Rectangle {
                            id: appSwitchTrack
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            radius: 9
                            color: appMenuItemRow.isInDock ? Commons.Color.accent : Qt.rgba(Commons.Color.popups.text.r, Commons.Color.popups.text.g, Commons.Color.popups.text.b, 0.25)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Rectangle {
                                id: appSwitchThumb
                                width: 12
                                height: 12
                                radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                x: appMenuItemRow.isInDock ? (appSwitchTrack.width - width - 3) : 3
                                color: appMenuItemRow.isInDock ? Commons.Color.background : Commons.Color.popups.text
                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: appItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (appMenuItemRow.isInDock) {
                                pickerWindow.root.removeDockWidget("omarchy.apps")
                            } else {
                                pickerWindow.root.addDockWidget("omarchy.apps")
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Commons.Color.composed("menu.border", "menu.border-alpha", Commons.Color.border, 0.25)
            }

            // 3. Widgets Section
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                // Other Widget Position Control
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 7
                    color: Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.05)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        spacing: 8

                        Text {
                            text: "Widget position:"
                            textFormat: Text.PlainText
                            font.family: Style.font.family
                            font.pixelSize: 11
                            font.bold: true
                            color: Commons.Color.menu.text
                            Layout.fillWidth: true
                        }

                        // Segmented Button: Left | Right
                        Row {
                            spacing: 3

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isLeft: (pickerWindow.root && pickerWindow.root.widgetPosition === "left")
                                color: isLeft ? Commons.Color.accent : (posLeftMouse.containsMouse ? Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Left"
                                    textFormat: Text.PlainText
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isLeft ? Commons.Color.background : Commons.Color.menu.text
                                }

                                MouseArea {
                                    id: posLeftMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("left")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("left")
                                    }
                                }
                            }

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isRight: (!pickerWindow.root || pickerWindow.root.widgetPosition !== "left")
                                color: isRight ? Commons.Color.accent : (posRightMouse.containsMouse ? Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Right"
                                    textFormat: Text.PlainText
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isRight ? Commons.Color.background : Commons.Color.menu.text
                                }

                                MouseArea {
                                    id: posRightMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("right")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("right")
                                    }
                                }
                            }
                        }
                    }
                }

                // Compact Widgets List View (Excluding omarchy.apps which is configured above)
                ListView {
                    id: widgetsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4

                    readonly property var standardWidgets: [
                        { id: "omarchy.clock", name: "Clock & Calendar", icon: "󰥔", defaultRegion: "center" },
                        { id: "omarchy.weather", name: "Weather", icon: "󰖐", defaultRegion: "center" },
                        { id: "omarchy.indicators", name: "Indicators", icon: "󰂚", defaultRegion: "center" },
                        { id: "omarchy.audio", name: "Volume & Audio", icon: "󰕾", defaultRegion: "right" },
                        { id: "omarchy.microphone", name: "Microphone", icon: "󰍬", defaultRegion: "right" },
                        { id: "omarchy.network", name: "Network & Wi-Fi", icon: "󰖩", defaultRegion: "right" },
                        { id: "omarchy.bluetooth", name: "Bluetooth", icon: "󰂯", defaultRegion: "right" },
                        { id: "omarchy.power", name: "Battery & Power", icon: "󰁹", defaultRegion: "right" },
                        { id: "omarchy.monitor", name: "Display", icon: "󰍹", defaultRegion: "right" },
                        { id: "omarchy.agents", name: "AI Agents", icon: "󰚩", defaultRegion: "right" },
                        { id: "omarchy.tailscale", name: "Tailscale VPN", icon: "󰖂", defaultRegion: "right" },
                        { id: "omarchy.keyboard-layout", name: "Keyboard layout", icon: "󰌌", defaultRegion: "right" },
                        { id: "omarchy.clipboard", name: "Clipboard", icon: "󰅌", defaultRegion: "right" },
                        { id: "omarchy.emojis", name: "Emojis", icon: "󰞅", defaultRegion: "right" },
                        { id: "omarchy.reminders", name: "Reminders", icon: "󰔢", defaultRegion: "right" },
                        { id: "omarchy.dropbox", name: "Dropbox", icon: "󰇣", defaultRegion: "right" },
                        { id: "omarchy.speedtest", name: "Speed Test", icon: "󰓅", defaultRegion: "right" },
                        { id: "omarchy.disk-speedtest", name: "Disk speed test", icon: "󰋊", defaultRegion: "right" },
                        { id: "omarchy.wifiqr", name: "Wi-Fi QR", icon: "󰒍", defaultRegion: "right" }
                    ]

                    model: {
                        var list = []
                        for (var i = 0; i < standardWidgets.length; i++) {
                            var w = standardWidgets[i]
                            // Only show installed widgets
                            var isInstalled = true
                            if (pickerWindow.shell && pickerWindow.shell.pluginRegistry && pickerWindow.shell.pluginRegistry.installedPlugins) {
                                isInstalled = (pickerWindow.shell.pluginRegistry.installedPlugins[w.id] !== undefined)
                            }
                            if (!isInstalled) continue
                            list.push(w)
                        }
                        return list
                    }

                    delegate: Rectangle {
                        id: rowItem
                        width: widgetsList.width
                        height: 38
                        radius: 7

                        readonly property bool isInDock: !!(pickerWindow.root && pickerWindow.root.dockWidgets && pickerWindow.root.dockWidgets.indexOf(modelData.id) !== -1)
                        readonly property bool isInBar: !!(pickerWindow.shell && pickerWindow.shell.pluginRegistry && typeof pickerWindow.shell.pluginRegistry.inBar === "function" && pickerWindow.shell.pluginRegistry.inBar(modelData.id))
                        readonly property bool isHovered: itemMouse.containsMouse

                        color: isInDock ? Commons.Color.composed("menu.selectedBackground", "menu.selectedBackground-alpha", Commons.Color.accent, isHovered ? 0.18 : 0.10) : (isHovered ? Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.06) : "transparent")
                        border.width: 1
                        border.color: isInDock ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.4) : (isHovered ? Commons.Color.composed("menu.border", "menu.border-alpha", Commons.Color.border, 0.2) : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Widget Icon
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                radius: 5
                                color: rowItem.isInDock ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.2) : Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.08)

                                DockGlyph {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    text: modelData.icon
                                    fontFamily: modelData.fontFamily ? modelData.fontFamily : Style.font.family
                                    fontSize: 14
                                    color: rowItem.isInDock ? Commons.Color.accent : Commons.Color.menu.text
                                }
                            }

                            // Widget Title & Badge (Strictly Left-Aligned)
                            Row {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                spacing: 8

                                Text {
                                    text: modelData.name
                                    textFormat: Text.PlainText
                                    font.family: Style.font.family
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Commons.Color.menu.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    height: 16
                                    width: badgeText.implicitWidth + 8
                                    radius: 4
                                    color: rowItem.isInDock ? Commons.Color.composed("accent", "accent-alpha", Commons.Color.accent, 0.25) : Commons.Color.composed("menu.text", "menu.text-alpha", Commons.Color.text, 0.08)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: rowItem.isInDock ? "Dock" : "Tray"
                                        textFormat: Text.PlainText
                                        font.family: Style.font.family
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: rowItem.isInDock ? Commons.Color.accent : Commons.Color.muted
                                    }
                                }
                            }

                            // Toggle Switch for Quick Transfer
                            Rectangle {
                                id: switchTrack
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 18
                                Layout.alignment: Qt.AlignVCenter
                                radius: 9
                                color: rowItem.isInDock ? Commons.Color.accent : Qt.rgba(Commons.Color.popups.text.r, Commons.Color.popups.text.g, Commons.Color.popups.text.b, 0.25)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Rectangle {
                                    id: switchThumb
                                    width: 12
                                    height: 12
                                    radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: rowItem.isInDock ? (switchTrack.width - width - 3) : 3
                                    color: rowItem.isInDock ? Commons.Color.background : Commons.Color.popups.text
                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rowItem.isInDock) {
                                    pickerWindow.root.removeDockWidget(modelData.id, modelData.defaultRegion)
                                } else {
                                    pickerWindow.root.addDockWidget(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
