// Render the actual settings body with an inert owner: no compositor or config writes.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'familiar-settings-'));
const quoted = value => JSON.stringify(require('node:url').pathToFileURL(path.resolve(value)).href);
const fixture = `
import QtQuick
import QtQuick.Layouts
import QtTest
import qs.Commons
import ${quoted('components')}
import ${quoted('.')}
import ${quoted('DockSettings.js')} as DockSettings
TestCase {
    id: root
    name: "SettingsLayout"
    width: 800; height: 560
    visible: true
    when: windowShown
    property int writes: 0
    SettingsStore {
        id: owner
        path: "/fictional/settings.json"
        fileShortcutsEnabled: true
        overlayMode: true
        titlebarsEnabled: true
        titlebarMode: "mac"
        titlebarStyle: "mac"
        readonly property string settingsError: error
        property string dockScreenPosition: "bottom"
        property var desktopTools: null
        property var capsLock: null
        property var borderResize: null
        property var commandShortcuts: null
        property var gestures: null
        property var windowMode: null
        property var taskbar: null
        property var setup: null
        property bool titlebarBusy: false
        property string titlebarMessage: ""
        function setPreference(key, value) { root.writes++ }
        function setDockEnabled(value) { root.writes++ }
        function setProfile(value) { root.writes++ }
        function setTitlebarMode(value) { root.writes++ }
        function setAutohide(value) { root.writes++ }
        function setKeybindMode(value) { root.writes++ }
        function setOverlayMode(value) { root.writes++ }
        function setVisibleWorkspace(value) { root.writes++ }
        function setWidgetsEnabled(value) { root.writes++ }
        function refreshTitlebars() { root.writes++ }
        function openWidgetPicker() { root.writes++ }
    }
    QtObject {
        id: setupFixture
        property var repairs: []
        function repair(style) { repairs = repairs.concat([style]) }
    }
    SignalSpy { id: closes; target: cardColumn; signalName: "closeRequested" }
    SettingsFrame {
        id: settingsWindow
        width: root.width; height: root.height
        contentHeight: cardColumn.implicitHeight
        SettingsContent {
            id: cardColumn
            service: owner
            navigation: settingsWindow
            workspaceOptions: [{value: "all", label: "All workspaces"}]
            taskbarActive: false
        }
    }
    function test_repairUsesTheSavedStyleOnlyWhenClicked() {
        compare(setupFixture.repairs.length, 0)
        owner.setup = setupFixture
        settingsWindow.page = "windows"
        settingsWindow.section = "titlebars"
        wait(30)
        mouseClick(findChild(cardColumn, "titlebar-repair"))
        compare(setupFixture.repairs, ["mac"])
        owner.titlebarStyle = "windows"
        mouseClick(findChild(cardColumn, "titlebar-repair"))
        compare(setupFixture.repairs, ["mac", "windows"])
        compare(closes.count, 2)
        compare(root.writes, 0)
        owner.setup = null
    }
    function test_pages() {
        for (var width of [800, 560]) {
            root.width = width
            for (var page of settingsWindow.pages) {
                settingsWindow.page = page.key
                var sections = settingsWindow.currentSections
                for (var section of sections.length ? sections : [{key: ""}]) {
                    settingsWindow.section = section.key
                    wait(30)
                    var scroll = findChild(settingsWindow, "settings-scroll")
                    verify(scroll.width > 250)
                    // Each preference section fits without scrolling at both supported widths.
                    if (page.key !== "help")
                        verify(settingsWindow.contentHeight <= scroll.height + 1, page.key + "/" + section.key + ": " + settingsWindow.contentHeight)
                    if (width === 800 && section.key === "layout")
                        grabImage(settingsWindow).save("/tmp/familiar-settings-layout.png")
                    console.log(width + " " + page.key + "/" + section.key + " height=" + Math.round(settingsWindow.contentHeight))
                }
            }
        }
        compare(writes, 0)
        compare(owner.profile, "general")
        compare(owner.dockEnabled, true)
        compare(owner.titlebarMode, "mac")
    }
}
`;
fs.writeFileSync(path.join(dir, 'tst_SettingsLayout.qml'), fixture);
fs.mkdirSync(path.join(dir, 'qs/Ui'), {recursive:true});
fs.writeFileSync(path.join(dir, 'qs/Ui/qmldir'), 'module qs.Ui\nBorderSurface 1.0 BorderSurface.qml\n');
fs.writeFileSync(path.join(dir, 'qs/Ui/BorderSurface.qml'), 'import QtQuick\nRectangle { property var borderSpec; property int borderLeft: 1; property int borderRight: 1 }\n');
const run = spawnSync(process.env.QMLTESTRUNNER || '/usr/lib/qt6/bin/qmltestrunner', ['-input',dir,'-import',dir,'-import',path.resolve('tests/imports')], {stdio:'inherit'});
if (run.error) throw run.error;
fs.rmSync(dir, {recursive:true,force:true});
process.exitCode = run.status === null ? 1 : run.status;
