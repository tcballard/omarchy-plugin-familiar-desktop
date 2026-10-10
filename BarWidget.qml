import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "DockSettings.js" as DockSettings
import "DockWidgets.js" as DockWidgets
import "DockCommands.js" as DockCommands
import "ShortcutLabels.js" as ShortcutLabels
import "components"

BarWidget {
  id: root
  moduleName: "io.github.tcballard.familiar-desktop"

  property var shell: root.bar ? root.bar.shell : null
  readonly property string profile: desktopService ? desktopService.profile : "general"
  readonly property string shortcutLabels: desktopService ? desktopService.shortcutLabels : "standard"
  readonly property bool fileShortcutsEnabled: desktopService ? desktopService.fileShortcutsEnabled : false
  readonly property bool dockEnabled: desktopService ? desktopService.dockEnabled : true
  readonly property string dockBackgroundOpacity: desktopService ? desktopService.dockBackgroundOpacity : "theme"
  readonly property string dockSize: desktopService ? desktopService.dockSize : "default"
  readonly property string dockPosition: desktopService ? desktopService.dockPosition : "auto"
  readonly property string titlebarSize: desktopService ? desktopService.titlebarSize : "default"
  readonly property bool titlebarsEnabled: desktopService ? desktopService.titlebarsEnabled : false
  readonly property string titlebarMode: desktopService ? desktopService.titlebarMode : "theme"
  readonly property string titlebarStyle: desktopService ? desktopService.titlebarStyle : "windows"
  readonly property string titlebarExclusions: desktopService ? desktopService.titlebarExclusions : ""
  property string titlebarStatusText: ""
  property bool titlebarOptionsOpen: false
  property bool gettingStartedOpen: false
  readonly property var desktopTools: desktopService ? desktopService.desktopTools : null
  Connections {
    target: root.desktopTools
    function onCompleted(operation) {
      if (operation === "show" || operation === "restore" || operation === "open-tool") root.close()
    }
  }
  readonly property var desktopService: root.shell && typeof root.shell.serviceFor === "function" ? root.shell.serviceFor(moduleName) : null
  readonly property string visibilityMode: desktopService ? desktopService.visibilityMode : "always"
  readonly property bool autohide: root.visibilityMode !== "always"
  readonly property bool overlayMode: desktopService ? desktopService.overlayMode : false
  readonly property string visibleWorkspace: desktopService ? desktopService.visibleWorkspace : "all"
  readonly property bool showFolderTitles: desktopService ? desktopService.showFolderTitles : true
  readonly property bool showBadges: desktopService ? desktopService.showBadges : true
  readonly property bool windowPreviews: desktopService ? desktopService.windowPreviews : true
  readonly property bool widgetsEnabled: desktopService ? desktopService.widgetsEnabled : true
  readonly property bool settingsOpen: settingsWindow.open
  onSettingsOpenChanged: {
    if (settingsOpen && desktopService) {
      if (desktopService.capsLock) desktopService.capsLock.run("status")
      if (desktopService.borderResize) desktopService.borderResize.run("status")
      if (desktopService.commandShortcuts) desktopService.commandShortcuts.run("status")
      if (desktopService.gestures) desktopService.gestures.run("status")
      if (desktopService.windowMode) desktopService.windowMode.run("status")
    }
  }
  readonly property string preferredVisibilityMode: desktopService ? desktopService.preferredVisibilityMode : "hover"
  readonly property string appMenuPosition: desktopService ? desktopService.appMenuPosition : "left"
  readonly property string widgetPosition: desktopService ? desktopService.widgetPosition : "right"
  readonly property var dockWidgets: desktopService ? desktopService.dockWidgets : ["omarchy.apps"]
  readonly property var widgetSavedPositions: desktopService ? desktopService.widgetSavedPositions : ({})
  readonly property string effectiveMode: root.autohide ? root.visibilityMode : (root.preferredVisibilityMode || "hover")

  function setPreference(key, value) {
    return desktopService ? desktopService.setPreference(key, value) : false
  }
  function setDockEnabled(value) { if (desktopService) desktopService.setDockEnabled(value) }
  function setProfile(value) { if (desktopService) desktopService.setProfile(value) }
  function setAutohide(value) { if (desktopService) desktopService.setAutohide(value) }
  function setKeybindMode(value) { if (desktopService) desktopService.setKeybindMode(value) }
  function setOverlayMode(value) { if (desktopService) desktopService.setOverlayMode(value) }
  function setVisibilityMode(value) { if (desktopService) desktopService.setVisibilityMode(value) }
  function setVisibleWorkspace(value) { if (desktopService) desktopService.setVisibleWorkspace(value) }

  function buildWorkspaceOptions() {
    var opts = [
      { value: "all", label: "All workspaces" }
    ]
    var existingIds = [1, 2, 3, 4, 5]
    if (Hyprland && Hyprland.workspaces && Hyprland.workspaces.values) {
      var values = Hyprland.workspaces.values
      for (var i = 0; i < values.length; i++) {
        var ws = values[i]
        if (ws && ws.id > 0 && ws.id <= 10 && existingIds.indexOf(ws.id) === -1) {
          existingIds.push(ws.id)
        }
      }
    }
    if (root.visibleWorkspace !== "all") {
      var selId = parseInt(root.visibleWorkspace, 10)
      if (!isNaN(selId) && selId > 0 && selId <= 10 && existingIds.indexOf(selId) === -1) {
        existingIds.push(selId)
      }
    }
    existingIds.sort(function(a, b) { return a - b })
    for (var j = 0; j < existingIds.length; j++) {
      var id = existingIds[j]
      var label = (id === 10 || id === 0) ? "Workspace 0" : ("Workspace " + id)
      opts.push({
        value: String(id),
        label: label
      })
    }
    return opts
  }

  readonly property var workspaceOptions: {
    var _dummy = Hyprland && Hyprland.workspaces && Hyprland.workspaces.values ? Hyprland.workspaces.values.length : 0
    var _sel = root.visibleWorkspace
    return root.buildWorkspaceOptions()
  }

  function setShowFolderTitles(value) { setPreference("showFolderTitles", value) }
  function setShowBadges(value) { setPreference("showBadges", value) }
  function setWidgetsEnabled(value) { setPreference("widgetsEnabled", value) }

  readonly property bool opened: settingsWindow.open
  function open() {
    if (desktopService && desktopService.setup && !desktopService.setup.ready) { desktopService.setup.show(); return }
    settingsWindow.open = true
  }
  function close() { settingsWindow.open = false }
  function toggle() { if (settingsWindow.open) close(); else open() }
  function closeForPopoutSwitch() { close() }

  // Drawer widgets stay mounted under an invisible host. They must not claim
  // to provide a taskbar and suppress the floating dock on that monitor.
  readonly property bool taskbarActive: root.visible && !!root.desktopService && root.desktopService.taskbarSelected && !root.vertical
  readonly property bool barButtonVisible: {
    // Plugin Drawer mounts another copy under an invisible host and may put
    // previews in its popup. Only the instance owned by a native bar slot may
    // join the bar's global click router.
    return root.visible && !!root.bar &&
      typeof root.bar.moduleWidgets === "function" &&
      root.bar.moduleWidgets(root.moduleName).indexOf(root) !== -1
  }
  implicitWidth: button.implicitWidth + (taskbarApps.active && taskbarApps.item ? taskbarApps.item.implicitWidth : 0)
  implicitHeight: Math.max(button.implicitHeight, taskbarApps.active && taskbarApps.item ? taskbarApps.item.implicitHeight : 0)
  Loader {
    id: taskbarApps
    active: root.taskbarActive && root.desktopService.dockAvailable
    anchors.left: button.right
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: TaskbarApps { service: root.desktopService; bar: root.bar }
  }

  WidgetButton {
    id: button
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: implicitWidth
    height: implicitHeight
    bar: root.bar
    interactive: root.barButtonVisible
    // Keep management recognisable beside the app strip, even without Nerd Fonts.
    text: root.taskbarActive ? "󰟀  Familiar" : "󰟀"
    fixedWidth: root.taskbarActive ? Math.max(100, Style.space(100)) : -1
    tooltipText: "Familiar settings"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.toggle()
      }
    }
  }

  SettingsModal {
    id: settingsWindow
    anchorItem: button
    owner: root
    bar: root.bar
    contentWidth: Style.space(800)
    contentHeight: cardColumn.implicitHeight
    onPageChanged: {
      if (page === "help" && root.desktopTools && !root.desktopTools.busy) root.desktopTools.run(["shortcuts"])
    }

    ColumnLayout {
      id: cardColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          visible: settingsWindow.page === "general"
          spacing: Style.space(16)
        Text {
          text: "Choose a starting layout. You can adjust the controls below."
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          font.family: Style.font.family
          font.pixelSize: 11
          color: Color.popups.text
          opacity: 0.8
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Repeater {
            model: [
              { key: "general", title: "General" },
              { key: "windows", title: "Windows" },
              { key: "mac", title: "Mac" }
            ]
            delegate: Rectangle {
              required property var modelData
              Layout.fillWidth: true
              height: 35
              radius: 7
              color: root.profile === modelData.key ? Color.accent :
                (presetMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent")
              border.width: root.profile === modelData.key ? 0 : 1
              border.color: Color.popups.border
              Text {
                anchors.centerIn: parent
                text: modelData.title
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: root.profile === modelData.key
                color: root.profile === modelData.key ? Color.background : Color.popups.text
              }
              MouseArea {
                id: presetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setProfile(modelData.key)
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          ActionButton {
            Layout.fillWidth: true
            text: "Show desktop"
            enabled: !!root.desktopTools && !root.desktopTools.busy
            onClicked: root.desktopTools.run(["show"])
          }
          ActionButton {
            Layout.fillWidth: true
            text: "Restore windows"
            enabled: !!root.desktopTools && !root.desktopTools.busy
            onClicked: root.desktopTools.run(["restore"])
          }
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.desktopTools ? (root.desktopTools.busy ? "Working…" : root.desktopTools.message) : "Familiar service is not available. Enable the plugin and reopen settings."
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          font.family: Style.font.family
          font.pixelSize: 12
          color: Color.popups.text
        }
        }
        Text {
          visible: settingsWindow.page === "general" && !!root.desktopService && !!root.desktopService.taskbar
          Layout.fillWidth: true
          text: root.desktopService && root.desktopService.taskbar
              ? (root.desktopService.taskbar.busy ? "Changing taskbar layout…" : root.desktopService.taskbar.message) : ""
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: Color.popups.text
        }
        GettingStarted {
          visible: settingsWindow.page === "help"
          Layout.fillWidth: true
          tools: root.desktopTools
          labelStyle: root.shortcutLabels
        }
        Repeater {
          model: [{key: "dockSize", label: "Dock and icons"}, {key: "titlebarSize", label: "Title bars and buttons"}]
          delegate: ColumnLayout {
            id: sizeRow
            visible: modelData.key === "dockSize" ? settingsWindow.shows("dock", "appearance") : settingsWindow.shows("windows", "titlebars")
            required property var modelData
            Layout.fillWidth: true
            Text {
              text: sizeRow.modelData.label
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: 12
              color: Color.popups.text
            }
            RowLayout {
              Layout.fillWidth: true
              Repeater {
                model: [{key: "default", label: "Default"}, {key: "large", label: "Large"}, {key: "extra-large", label: "Extra large"}]
                delegate: ActionButton {
                  required property var modelData
                  Layout.fillWidth: true
                  text: modelData.label
                  selected: root[sizeRow.modelData.key] === modelData.key
                  onClicked: { root.setPreference(sizeRow.modelData.key, modelData.key) }
                }
              }
            }
          }
        }

        DockDropdown {
          objectName: "dock-background-opacity"
          Layout.fillWidth: true
          visible: settingsWindow.shows("dock", "appearance") && !root.taskbarActive
          label: "Dock background opacity"
          value: root.dockBackgroundOpacity
          options: [
            { value: "theme", label: "Follow theme" },
            { value: "0", label: "0% — Transparent" },
            { value: "25", label: "25%" },
            { value: "50", label: "50%" },
            { value: "75", label: "75%" },
            { value: "100", label: "100% — Opaque" }
          ]
          onChanged: function(value) {
            root.setPreference("dockBackgroundOpacity", DockSettings.normalizeBackgroundOpacity(value))
          }
        }

        InputPreferenceSettings {
          visible: settingsWindow.shows("windows", "resizing")
          Layout.fillWidth: true
          controller: root.desktopService ? root.desktopService.borderResize : null
          title: "Resize with the mouse"
          explanation: "Drag a window edge or corner to resize, without holding a modifier key. Adds a 15-pixel grab area and resize cursor. Tiled resizing follows your Hyprland layout; floating windows resize freely. Use configuration restores your original settings."
          enableLabel: "Enable border dragging"
        }

        WindowModeSettings {
          visible: settingsWindow.shows("windows", "layout")
          Layout.fillWidth: true
          controller: root.desktopService ? root.desktopService.windowMode : null
          labelStyle: root.shortcutLabels
        }

        ColumnLayout {
          visible: settingsWindow.shows("keyboard", "shortcuts")
          Layout.fillWidth: true
          Text {
            text: "Shortcut labels"
            textFormat: Text.PlainText
            font.family: Style.font.family
            color: Color.popups.text
          }
          Repeater {
            model: [{key: "standard", label: "Super / Alt / Ctrl"}, {key: "mac", label: "Command / Option / Control"}]
            delegate: ActionButton {
              required property var modelData
              Layout.fillWidth: true
              text: modelData.label
              selected: root.shortcutLabels === modelData.key
              onClicked: { root.setPreference("shortcutLabels", modelData.key) }
            }
          }
          Text {
            Layout.fillWidth: true
            text: "Changes the names shown in Familiar. Your keybindings and copyable configuration stay the same."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: 12
            color: Color.popups.text
          }
        }

        InputPreferenceSettings {
          visible: settingsWindow.shows("keyboard", "shortcuts")
          Layout.fillWidth: true
          controller: root.desktopService ? root.desktopService.commandShortcuts : null
          title: "Command editing shortcuts"
          explanation: "Opt-in: replaces Super+C/V/X/A/Z and Super+Shift+Z with copy, paste, cut, select all, undo and redo. Other desktop shortcuts stay as configured. Known terminals (including Kitty, Alacritty, Foot, WezTerm and Ghostty) use Ctrl+Shift+C/V; other editing aliases pass through there. Custom terminal classes may need support before enabling. This changes behaviour independently of the label preference. Use configuration restores the original bindings."
          enableLabel: "Enable Command editing shortcuts"
        }

        GesturesSettings {
          visible: settingsWindow.shows("keyboard", "gestures")
          Layout.fillWidth: true
          controller: root.desktopService ? root.desktopService.gestures : null
        }

        CapsLockSettings {
          visible: settingsWindow.shows("keyboard", "keys")
          Layout.fillWidth: true
          controller: root.desktopService ? root.desktopService.capsLock : null
        }

        ColumnLayout {
          visible: settingsWindow.shows("windows", "titlebars")
          Layout.fillWidth: true
          spacing: 6
          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Title bars with close, minimise and maximise. Restore minimised windows from the dock."
            font.family: Style.font.family
            font.pixelSize: 11
            color: Color.popups.text
          }
          RowLayout {
            Layout.fillWidth: true
            Repeater {
              model: [ { key: "theme", title: "Theme" }, { key: "off", title: "Off" }, { key: "mac", title: "Mac" }, { key: "windows", title: "Windows" } ]
              delegate: Rectangle {
                required property var modelData
                readonly property bool selected: root.titlebarMode === modelData.key
                Layout.fillWidth: true
                height: 32
                radius: 7
                color: selected ? Color.accent : "transparent"
                border.width: selected ? 0 : 1
                border.color: Color.popups.border
                Text {
                  anchors.centerIn: parent
                  text: modelData.title
                  font.family: Style.font.family
                  font.pixelSize: 12
                  color: parent.selected ? Color.background : Color.popups.text
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (root.desktopService) root.desktopService.setTitlebarMode(modelData.key)
                  }
                }
              }
            }
          }
          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: root.desktopService ? root.desktopService.titlebarMessage : "Window controls require the Familiar Desktop service."
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.muted
          }
          Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: titlebarSetupMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
            border.width: 1
            border.color: Color.popups.border
            Text {
              anchors.centerIn: parent
              text: "Set up or repair window controls"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.popups.text
            }
            MouseArea {
              id: titlebarSetupMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.desktopService && root.desktopService.setup) {
                  root.close()
                  root.desktopService.setup.repair(root.titlebarStyle)
                }
              }
            }
          }
          Text {
            visible: root.titlebarMode !== "off"
            text: "Skip apps with their own title bars (window classes, comma-separated)"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: 10
            color: Color.muted
          }
          Rectangle {
            visible: root.titlebarMode !== "off"
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: titlebarExclusionsInput.activeFocus ? Color.accent : Color.popups.border
            TextInput {
              id: titlebarExclusionsInput
              anchors.fill: parent
              anchors.margins: 7
              text: root.titlebarExclusions
              maximumLength: 6400
              clip: true
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.popups.text
              selectByMouse: true
              onEditingFinished: {
                root.setPreference("titlebarExclusions", text)
              }
            }
          }
          Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: "transparent"
            Text {
              anchors.centerIn: parent
              text: root.desktopService && root.desktopService.titlebarBusy ? "Applying…" : "Refresh window controls"
              font.family: Style.font.family
              font.pixelSize: 11
              color: Color.popups.text
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              enabled: root.desktopService && !root.desktopService.titlebarBusy
              onClicked: root.desktopService.refreshTitlebars()
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          visible: settingsWindow.page === "dock"
          spacing: Style.space(8)
        // 1. Enable dock toggle row
        Rectangle {
          id: dockEnabledRow
          visible: settingsWindow.section === "appearance"
          activeFocusOnTab: true
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Enable dock"
          Accessible.checkable: true
          Accessible.checked: root.dockEnabled
          Accessible.onPressAction: root.setDockEnabled(!root.dockEnabled)
          Keys.onSpacePressed: root.setDockEnabled(!root.dockEnabled)
          Keys.onReturnPressed: root.setDockEnabled(!root.dockEnabled)
          border.width: activeFocus ? 2 : 0
          border.color: Color.accent
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleDockEnabledMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Enable dock"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Show dock panel on screen"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchDockEnabledTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.minimumWidth: 36
              Layout.maximumWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.dockEnabled ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchDockEnabledThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.dockEnabled ? (switchDockEnabledTrack.width - width - 3) : 3
                color: root.dockEnabled ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleDockEnabledMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setDockEnabled(!root.dockEnabled)
            }
          }
        }

        DockDropdown {
          Layout.fillWidth: true
          visible: settingsWindow.section === "appearance" && !root.taskbarActive
          label: "Dock position"
          value: root.dockPosition
          options: [
            { value: "auto", label: "Automatic (layout default)" },
            { value: "bottom", label: "Bottom" },
            { value: "left", label: "Left" },
            { value: "right", label: "Right" }
          ]
          onChanged: function(value) {
            root.setPreference("dockPosition", DockSettings.normalizeDockPosition(value))
          }
        }

        Text {
          Layout.fillWidth: true
          visible: settingsWindow.section === "appearance"
          text: root.taskbarActive ? "Windows uses the native bottom taskbar. Bar height, appearance and widgets follow Omarchy’s bar settings. Choose General or Mac to restore your previous bar." : root.dockPosition !== "auto" && root.desktopService
              && root.desktopService.dockScreenPosition !== root.dockPosition
              ? "Omarchy’s bar uses that edge. The dock uses the opposite edge until it is free."
              : "Your position choice is kept when you change layouts. Automatic follows the layout default."
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: Color.muted
        }

        // File shortcuts
        Rectangle {
          visible: settingsWindow.section === "extras"
          Layout.fillWidth: true
          implicitHeight: 38
          radius: 8
          color: Color.composed("popups.text", "popups.text-alpha", Color.text, 0.08)
          Text {
            anchors.centerIn: parent
            text: (root.fileShortcutsEnabled ? "✓  " : "+  ") + "Home, Downloads and Bin shortcuts"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: 11
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.setPreference("fileShortcutsEnabled", !root.fileShortcutsEnabled) }
          }
        }

        DockDropdown {
          Layout.fillWidth: true
          visible: settingsWindow.section === "visibility"
          label: "Show apps from"
          value: root.visibleWorkspace
          options: root.workspaceOptions
          onChanged: function(value) { root.setVisibleWorkspace(value) }
        }

        // 3. Autohide dock (edge hover)
        Rectangle {
          id: autohideRow
          visible: settingsWindow.section === "visibility"
          activeFocusOnTab: true
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Autohide dock"
          Accessible.checkable: true
          Accessible.checked: autohideRow.active
          Accessible.onPressAction: root.setAutohide(!autohideRow.active)
          Keys.onSpacePressed: root.setAutohide(!autohideRow.active)
          Keys.onReturnPressed: root.setAutohide(!autohideRow.active)
          border.width: activeFocus ? 2 : 0
          border.color: Color.accent
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          readonly property bool active: root.dockEnabled && (root.visibilityMode === "hover" || root.visibilityMode === "hybrid")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Autohide dock"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Reveal on screen-edge hover"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            Rectangle {
              id: switchTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.minimumWidth: 36
              Layout.maximumWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: autohideRow.active ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: autohideRow.active ? (switchTrack.width - width - 3) : 3
                color: autohideRow.active ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setAutohide(!autohideRow.active)
            }
          }
        }

        // 4. Keyboard shortcut toggle
        Rectangle {
          id: keybindRow
          visible: settingsWindow.section === "visibility"
          activeFocusOnTab: true
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Keyboard shortcut"
          Accessible.checkable: true
          Accessible.checked: keybindRow.active
          Accessible.onPressAction: root.setKeybindMode(!keybindRow.active)
          Keys.onSpacePressed: root.setKeybindMode(!keybindRow.active)
          Keys.onReturnPressed: root.setKeybindMode(!keybindRow.active)
          border.width: activeFocus ? 2 : 0
          border.color: Color.accent
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleKeybindMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          readonly property bool active: root.dockEnabled && (root.visibilityMode === "keybind" || root.visibilityMode === "hybrid")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Keyboard shortcut"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Summon dock on demand"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            Rectangle {
              id: switchKeybindTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.minimumWidth: 36
              Layout.maximumWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: keybindRow.active ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchKeybindThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: keybindRow.active ? (switchKeybindTrack.width - width - 3) : 3
                color: keybindRow.active ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleKeybindMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setKeybindMode(!keybindRow.active)
            }
          }
        }

        // 5. Shortcut Hint (smoothly appears ONLY when Keyboard shortcut is active)
        ColumnLayout {
          id: shortcutHintCard
          Layout.fillWidth: true
          Layout.leftMargin: 2
          Layout.rightMargin: 2
          Layout.preferredHeight: (root.dockEnabled && (root.visibilityMode === "keybind" || root.visibilityMode === "hybrid")) ? 64 : 0
          Layout.minimumHeight: 0
          clip: true
          visible: settingsWindow.section === "visibility" && Layout.preferredHeight > 0
          opacity: (root.dockEnabled && (root.visibilityMode === "keybind" || root.visibilityMode === "hybrid")) ? 1.0 : 0.0
          spacing: 4
          Behavior on Layout.preferredHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

          Text {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            text: "Add to ~/.config/hypr/bindings.lua:"
            textFormat: Text.PlainText
            font.family: Style.font.family
            font.pixelSize: 10
            font.bold: true
            color: Color.popups.text
            elide: Text.ElideRight
          }

          Rectangle {
            id: cmdPill
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.minimumHeight: 44
            Layout.maximumHeight: 44
            radius: 6
            color: cmdMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : Color.composed("popups.border", "popups.border-alpha", Color.border, 0.25)
            border.width: 1
            border.color: cmdMouse.containsMouse ? Color.accent : Color.composed("popups.border", "popups.border-alpha", Color.border, 0.4)
            Behavior on color { ColorAnimation { duration: 120 } }

            property bool copied: false
            Timer {
              id: copyTimer
              interval: 1800
              repeat: false
              onTriggered: cmdPill.copied = false
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              Text {
                id: cmdText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: cmdPill.copied ? "✓ Copied to clipboard!" : "o.bind(\"SUPER + D\", \"Toggle Dock\",\n  \"omarchy-shell -q io.github.tcballard.familiar-desktop toggleReveal\")"
                textFormat: Text.PlainText
                font.family: !cmdPill.copied ? (Style.font.monospace || "monospace") : Style.font.family
                font.pixelSize: !cmdPill.copied ? 9 : 10
                lineHeight: 1.18
                font.bold: cmdPill.copied
                color: cmdPill.copied ? Color.accent : Color.popups.text
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
              }

              DockGlyph {
                width: 14
                height: 14
                text: cmdPill.copied ? "󰄬" : "󰆏"
                fontFamily: Style.font.family
                fontSize: 11
                color: cmdPill.copied ? Color.accent : Color.muted
              }
            }

            MouseArea {
              id: cmdMouse
              anchors.fill: parent
              enabled: root.dockEnabled && (root.visibilityMode === "keybind" || root.visibilityMode === "hybrid")
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var cmd = 'o.bind("SUPER + D", "Toggle Dock", "omarchy-shell -q io.github.tcballard.familiar-desktop toggleReveal")'
                try {
                  Quickshell.clipboardText = cmd
                } catch(e) {}
                if (root.bar && typeof root.bar.run === "function") {
                  root.bar.run(["wl-copy", cmd])
                }
                cmdPill.copied = true
                copyTimer.restart()
              }
            }
          }
        }

        // Toggle Overlay Mode Row
        Rectangle {
          id: overlayRow
          visible: settingsWindow.section === "visibility"
          activeFocusOnTab: true
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Overlay mode"
          Accessible.checkable: true
          Accessible.checked: root.overlayMode
          Accessible.onPressAction: root.setOverlayMode(!root.overlayMode)
          Keys.onSpacePressed: root.setOverlayMode(!root.overlayMode)
          Keys.onReturnPressed: root.setOverlayMode(!root.overlayMode)
          border.width: activeFocus ? 2 : 0
          border.color: Color.accent
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleOverlayMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Overlay mode"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Float on top of application windows"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchOverlayTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.overlayMode ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchOverlayThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.overlayMode ? (switchOverlayTrack.width - width - 3) : 3
                color: root.overlayMode ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleOverlayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setOverlayMode(!root.overlayMode)
            }
          }
        }

        ActionButton {
          Layout.fillWidth: true
          visible: settingsWindow.section === "extras"
          text: "Window previews on hover: " + (root.windowPreviews ? "On" : "Off")
          selected: root.windowPreviews
          onClicked: { root.setPreference("windowPreviews", !root.windowPreviews) }
        }

        // Toggle Notification Badges Row
        Rectangle {
          id: badgesRow
          visible: settingsWindow.section === "extras"
          activeFocusOnTab: true
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Notification badges"
          Accessible.checkable: true
          Accessible.checked: root.showBadges
          Accessible.onPressAction: root.setShowBadges(!root.showBadges)
          Keys.onSpacePressed: root.setShowBadges(!root.showBadges)
          Keys.onReturnPressed: root.setShowBadges(!root.showBadges)
          border.width: activeFocus ? 2 : 0
          border.color: Color.accent
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleBadgesMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Notification badges"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Show unread counter on app icons"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchBadgesTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.showBadges ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchBadgesThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.showBadges ? (switchBadgesTrack.width - width - 3) : 3
                color: root.showBadges ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleBadgesMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setShowBadges(!root.showBadges)
            }
          }
        }

        // Toggle Widgets in Dock Row
        Rectangle {
          id: widgetsRow
          visible: settingsWindow.section === "extras"
          activeFocusOnTab: true
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Dock widgets"
          Accessible.checkable: true
          Accessible.checked: root.widgetsEnabled
          Accessible.onPressAction: root.setWidgetsEnabled(!root.widgetsEnabled)
          Keys.onSpacePressed: root.setWidgetsEnabled(!root.widgetsEnabled)
          Keys.onReturnPressed: root.setWidgetsEnabled(!root.widgetsEnabled)
          border.width: activeFocus ? 2 : 0
          border.color: Color.accent
          Layout.fillWidth: true
          height: 42
          radius: 8
          color: toggleWidgetsMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: "Dock widgets"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: true
                color: Color.popups.text
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: "Integrate app menu and bar widgets"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 10
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Custom Smooth Toggle Switch
            Rectangle {
              id: switchWidgetsTrack
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
              Layout.preferredWidth: 36
              Layout.preferredHeight: 20
              width: 36
              height: 20
              radius: 10
              color: root.widgetsEnabled ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
              Behavior on color { ColorAnimation { duration: 180 } }

              Rectangle {
                id: switchWidgetsThumb
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: root.widgetsEnabled ? (switchWidgetsTrack.width - width - 3) : 3
                color: root.widgetsEnabled ? Color.background : Color.popups.text
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              }
            }
          }

          MouseArea {
            id: toggleWidgetsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setWidgetsEnabled(!root.widgetsEnabled)
            }
          }
        }

        // Configure Widgets Action Button
        Rectangle {
          id: configureWidgetsRow
          visible: settingsWindow.section === "extras"
          Layout.fillWidth: true
          Layout.preferredHeight: 40
          radius: 8
          opacity: root.widgetsEnabled ? 1.0 : 0.4
          enabled: root.widgetsEnabled
          color: configureWidgetsMouse.containsMouse ? Color.composed("accent", "accent-alpha", Color.accent, 0.2) : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.08)
          border.width: 1
          border.color: configureWidgetsMouse.containsMouse ? Color.accent : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }
          Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

          Text {
            anchors.centerIn: parent
            text: "Configure dock widgets"
            textFormat: Text.PlainText
            font.family: Style.font.family
            font.pixelSize: 11
            font.bold: true
            color: configureWidgetsMouse.containsMouse ? Color.accent : Color.popups.text
            renderType: Text.CurveRendering
            font.hintingPreference: Font.PreferNoHinting
            Behavior on color { ColorAnimation { duration: 120 } }
          }

          MouseArea {
            id: configureWidgetsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              var sh = root.shell || (root.bar ? root.bar.shell : null)
              var dockSvc = (sh && typeof sh.serviceFor === "function") ? sh.serviceFor("io.github.tcballard.familiar-desktop") : null
              if (dockSvc && typeof dockSvc.openWidgetPicker === "function") {
                dockSvc.openWidgetPicker()
              } else if (root.bar && typeof root.bar.run === "function") {
                root.bar.run("omarchy-shell io.github.tcballard.familiar-desktop openWidgetPicker")
              } else {
                Util.execDetached("omarchy-shell io.github.tcballard.familiar-desktop openWidgetPicker")
              }
            }
          }
        }
        }
      }
    }
  }
