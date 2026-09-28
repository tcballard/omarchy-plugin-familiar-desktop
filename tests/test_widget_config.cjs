const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('DockWidgets.js', 'utf8').replace(/^\.pragma library\s*/, '');
const context = { console };
vm.createContext(context);
vm.runInContext(source, context);

const initial = { bar: { layout: { left: [], center: [], right: [{ id: 'example.clock' }] } }, plugins: [] };

function run(hostResult) {
  let hostCalls = 0;
  let fileWrites = 0;
  let disk = JSON.stringify(initial);
  const shell = { mutateShellConfig(mutator) { hostCalls++; if (hostResult) mutator(JSON.parse(disk)); return hostResult; } };
  const file = { text: () => disk, setText(value) { fileWrites++; disk = value; } };
  context.switchDockWidgetInBar(shell, 'example.clock', [], {}, file);
  return { hostCalls, fileWrites, disk: JSON.parse(disk) };
}

const handled = run(true);
assert.equal(handled.hostCalls, 1);
assert.equal(handled.fileWrites, 0, 'successful host write must not be repeated against shell.json');

const declined = run(false);
assert.equal(declined.hostCalls, 1);
assert.equal(declined.fileWrites, 1, 'declined host write must use the file fallback');
assert.equal(declined.disk.bar.layout.right.length, 0);
assert.equal(declined.disk.plugins[0].id, 'example.clock');
console.log('widget config fallback: passed');
