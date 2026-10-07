const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync('DockMatcher.js', 'utf8').replace(/^\.pragma library\s*/m, ''), model);

const appId = 'org.example.browser';
const a = {appId, title: 'A', address: '0xa'};
const b = {appId, title: 'B', address: '0xb'};
const c = {appId, title: 'C', address: '0xc'};
const other = {appId: 'org.example.editor', title: 'Editor', address: '0xd'};
const entries = [{id: appId, name: 'Browser', icon: 'browser', execString: 'browser'}];
let live = [a, b, c, other];
let history = [];
function focus(top) {
  history = model.rememberWindowFocus(history, live, top);
}
function browser(pins, active = other, minimized = []) {
  const items = model.buildDockItems(pins, live, active, entries, null, {}, {}, 20, minimized, history);
  return items.flatMap(item => item.isStack ? Array.from(item.subApps) : [item]).find(item => item.appId === appId);
}
for (const pins of [[appId], [], [{isStack: true, id: 'work', apps: [appId]}]]) {
  live = [a, b, c, other];
  history = [];
  focus(c);
  focus(b);
  focus(other);
  let item = browser(pins);
  assert.equal(item.toplevels[item.activeTopIndex], b, 'return to most recently focused app window');
  assert.equal(item.isActive, false);
  assert.deepEqual(Array.from(item.toplevels), [a, b, c], 'preview/cycle order must stay stable');
  item = browser(pins, a);
  assert.equal(item.toplevels[item.activeTopIndex], a, 'current focus wins over history');
  item = browser(pins, other, [b]);
  assert.equal(item.toplevels[item.activeTopIndex], b, 'last-used minimised window can be restored');
  live = [a, c, other];
  focus(other);
  item = browser(pins);
  assert.equal(item.toplevels[item.activeTopIndex], c, 'closed last-used window falls back to next recent survivor');
  const replacement = {...b};
  live = [a, replacement, c, other];
  focus(other);
  item = browser(pins);
  assert.equal(item.toplevels[item.activeTopIndex], c, 'reused address/title does not inherit old focus');
  assert.equal(history.includes(b), false);
}
live = [a, b, c, other];
history = [];
assert.equal(browser([appId]).activeTopIndex, 0, 'no history keeps deterministic fallback');
for (let n = 0; n < 100; n++) focus(live[n % live.length]);
assert.equal(history.length, 4, 'history is bounded by live windows');
history = model.rememberWindowFocus(history, [], null);
assert.equal(history.length, 0, 'closing all windows releases history');
console.log('last-used window selection, stable order, closure and replacement: passed');
