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
assert.deepEqual(plain(widgets.normalizeDockWidgets(['omarchy.apps', 'omarchy.clock', 'omarchy.audio'])), ['omarchy.apps', 'omarchy.clock', 'omarchy.audio']);
assert.deepEqual(plain(widgets.normalizeDockWidgets(['../../evil', 'x; touch /tmp/evil', 'io.github.tcballard.familiar-desktop'])), []);
assert.deepEqual(plain(widgets.normalizeDockWidgets([])), []);
const selection = ['omarchy.apps', 'omarchy.clock', 'omarchy.audio'];
assert.deepEqual(plain(widgets.getDockWidgetLayout(true, 'left', false, selection, 'right')), { leftWidgets: [], rightWidgets: [] });
assert.deepEqual(selection, ['omarchy.apps', 'omarchy.clock', 'omarchy.audio']);
assert.deepEqual(plain(widgets.getDockWidgetLayout(true, 'left', true, selection, 'right')), { leftWidgets: ['omarchy.apps'], rightWidgets: ['omarchy.clock', 'omarchy.audio'] });
const args = ['printf', '%s', "spaces ' quotes \" $HOME $(printf INJECTED) `printf INJECTED`\nnext line"];
let received;
commands.run({ execArgv(argv) { received = plain(argv); } }, args);
assert.deepEqual(received, args);
commands.run({ execDetached(cmd) { received = cmd; } }, args);
assert.equal(execFileSync('/bin/sh', ['-c', received], { encoding: 'utf8' }), args[2]);
assert.equal(commands.run({ execArgv() { throw Error('must reject NUL'); } }, ['x', '\x00']), false);
console.log('widget selection and literal command arguments: passed');

// Exercise the production schema through its module interface.
const schema = require('./helpers/load-js.cjs')('components/SettingsSchema.js');
const legacy = {shortcutLabels:'mac',widgetsEnabled:false,dockWidgets:selection,dockSize:'large',titlebarSize:'extra-large',titlebarsEnabled:true,titlebarStyle:'mac',showFolderTitles:false,unknownFutureOption:{enabled:true}};
const normalized = schema.normalize(legacy);
assert.equal(normalized.titlebarMode,'mac');
assert.equal(normalized.showFolderTitles,false);
assert.equal(normalized.widgetsEnabled,false);
assert.deepEqual(plain(normalized.dockWidgets),selection);
const saved = JSON.parse(schema.encode(legacy,normalized));
assert.deepEqual(saved.unknownFutureOption,{enabled:true});
assert.equal(saved.shortcutLabels,'mac');
assert.equal(saved.titlebarSize,'extra-large');
for(const position of ['auto','bottom','left','right']) {
  assert.equal(JSON.parse(schema.encode(legacy,{...normalized,dockPosition:position})).dockPosition,position);
}
assert.deepEqual(plain(schema.normalize({dockWidgets:[]}).dockWidgets),[]);
assert.equal(schema.normalize({titlebarMode:'theme',titlebarsEnabled:false}).titlebarMode,'theme');
assert.equal(schema.normalize({}).dockPosition,'auto');
console.log('single settings schema preserves preferences, empty selections and unknown fields: passed');
