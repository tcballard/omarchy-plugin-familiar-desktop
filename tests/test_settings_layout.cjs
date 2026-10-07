// Render the actual settings body with an inert owner: no compositor or config writes.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const source = fs.readFileSync('BarWidget.qml', 'utf8');
const start = source.indexOf('    ColumnLayout {\n      id: cardColumn');
const end = source.lastIndexOf('\n    }\n  }');
if (start < 0 || end < start) throw new Error('Cannot locate production settings content');
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
    property var desktopService: null
    property var desktopTools: null
    property var bar: null
    property var shell: null
    property string profile: "general"
    property string shortcutLabels: "standard"
    property string dockSize: "default"
    property string titlebarSize: "default"
    property string titlebarMode: "mac"
    property string titlebarStyle: "mac"
    property string titlebarExclusions: ""
    property string dockPosition: "auto"
    property string visibilityMode: "hybrid"
    property string visibleWorkspace: "all"
    property bool titlebarsEnabled: true
    property bool dockEnabled: true
    property bool fileShortcutsEnabled: true
    property bool overlayMode: true
    property bool showBadges: true
    property bool widgetsEnabled: true
    property var workspaceOptions: [{value: "all", label: "All workspaces"}]
    property int writes: 0
    function saveSettings() { writes++ }
    SettingsFrame {
        id: settingsWindow
        width: root.width; height: root.height
        contentHeight: cardColumn.implicitHeight
        ${source.slice(start,end)}
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
        compare(profile, "general")
        compare(dockEnabled, true)
        compare(titlebarMode, "mac")
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
