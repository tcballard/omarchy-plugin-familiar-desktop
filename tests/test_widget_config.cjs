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
