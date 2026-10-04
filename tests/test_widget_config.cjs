const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
function load(file) {
  const source = fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/, '');
  const context = { console };
  vm.createContext(context);
  vm.runInContext(source, context);
  return context;
}
const widgets = load('DockWidgets.js');
const commands = load('DockCommands.js');
const plain = value => JSON.parse(JSON.stringify(value));
assert.deepEqual(plain(widgets.normalizeDockWidgets(['omarchy.apps', 'omarchy.clock', 'omarchy.audio'])), ['omarchy.apps', 'omarchy.audio']);
assert.deepEqual(plain(widgets.normalizeDockWidgets(['../../evil', 'x; touch /tmp/evil', 'io.github.tcballard.familiar-desktop'])), []);
assert.deepEqual(plain(widgets.normalizeDockWidgets([])), []);
const selection = ['omarchy.apps', 'omarchy.clock'];
assert.deepEqual(plain(widgets.getDockWidgetLayout(true, 'left', false, selection, 'right')), { leftWidgets: [], rightWidgets: [] });
assert.deepEqual(selection, ['omarchy.apps', 'omarchy.clock']);
assert.deepEqual(plain(widgets.getDockWidgetLayout(true, 'left', true, selection, 'right')), { leftWidgets: ['omarchy.apps'], rightWidgets: ['omarchy.clock'] });
const args = ['printf', '%s', "spaces ' quotes \" $HOME $(printf INJECTED) `printf INJECTED`\nnext line"];
let received;
commands.run({ execArgv(argv) { received = plain(argv); } }, args);
assert.deepEqual(received, args);
commands.run({ execDetached(cmd) { received = cmd; } }, args);
assert.equal(execFileSync('/bin/sh', ['-c', received], { encoding: 'utf8' }), args[2]);
assert.equal(commands.run({ execArgv() { throw Error('must reject NUL'); } }, ['x', '\x00']), false);
console.log('widget selection and literal command arguments: passed');

// Execute the actual settings handlers, without a Quickshell UI, to exercise
// both writers/readers when widgets are disabled and after a reload.
const settings = load('DockSettings.js');
for (const filename of ['DockPanel.qml', 'BarWidget.qml']) {
  const source = fs.readFileSync(filename, 'utf8');
  const indent = filename === 'DockPanel.qml' ? '    ' : '  ';
  const root = { isSavingSettings: false, widgetsEnabled: false, dockWidgets: selection.slice() };
  let disk = JSON.stringify({ widgetsEnabled: false, dockWidgets: selection, dockSize: "large", titlebarSize: "extra-large", titlebarsEnabled: true, titlebarStyle: "mac", titlebarExclusions: "org.gnome.Nautilus,kitty" });
  const context = {
    root, DockSettings: settings, DockModel: widgets, DockWidgets: widgets,
    settingsFile: { text: () => disk, setText: value => { disk = value; } },
    saveSettingsTimer: { restart() {} }
  };
  vm.createContext(context);
  for (const name of ['readSettings', 'saveSettings']) {
    const start = source.indexOf(indent + 'function ' + name + '() {');
    assert.ok(start >= 0);
    const end = source.indexOf('\n' + indent + '}', start) + indent.length + 2;
    vm.runInContext(source.slice(start, end), context);
  }
  context.readSettings();
  assert.equal(root.widgetsEnabled, false);
  assert.equal(root.titlebarsEnabled, true);
  assert.equal(root.titlebarStyle, "mac");
  assert.equal(root.titlebarMode, "mac");
  assert.equal(root.titlebarExclusions, "org.gnome.Nautilus,kitty");
  assert.deepEqual(plain(root.dockWidgets), selection);
  assert.equal(root.dockSize, "large");
  assert.equal(root.titlebarSize, "extra-large");
  context.saveSettings();
  assert.equal(JSON.parse(disk).dockSize, "large");
  assert.equal(JSON.parse(disk).titlebarSize, "extra-large");
  assert.deepEqual(JSON.parse(disk).dockWidgets, selection);
  assert.equal(JSON.parse(disk).titlebarsEnabled, true);
  assert.equal(JSON.parse(disk).titlebarStyle, "mac");
  assert.equal(JSON.parse(disk).titlebarMode, "mac");
  assert.equal(JSON.parse(disk).titlebarExclusions, "org.gnome.Nautilus,kitty");
  root.isSavingSettings = false;
  root.dockWidgets = [];
  context.readSettings();
  assert.deepEqual(plain(root.dockWidgets), selection);
  disk = JSON.stringify({ titlebarMode: "theme", titlebarsEnabled: false, titlebarStyle: "mac" });
  context.readSettings();
  assert.equal(root.titlebarMode, "theme");
  context.saveSettings();
  assert.equal(JSON.parse(disk).titlebarMode, "theme");
}
console.log('both QML settings handlers preserve disabled widget selections: passed');
