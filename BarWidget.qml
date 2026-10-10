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

    Loader {
      id: cardColumn
      active: !!root.desktopService
      width: parent.width
      objectName: "settings-content"
      sourceComponent: SettingsContent {
        service: root.desktopService
        navigation: settingsWindow
        workspaceOptions: root.workspaceOptions
        taskbarActive: root.taskbarActive
        onCloseRequested: root.close()
        onCopyRequested: function(text) {
          try { Quickshell.clipboardText = text } catch (e) {}
          if (root.bar && typeof root.bar.run === "function") root.bar.run(["wl-copy", text])
        }
      }
    }
  }
}
