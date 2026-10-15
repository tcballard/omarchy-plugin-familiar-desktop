const assert = require('node:assert/strict');
const loadJS = require('./helpers/load-js.cjs');
const matcher = loadJS('DockMatcher.js');

// CLI apps running inside terminal windows must be attributed to the window
// they actually run in. The /proc scanner reports one entry per terminal
// window ({address, app}); a predictive launch hint is only a guess and must
// expire with the hint instead of sticking to whichever terminal it touched.

const entries = [
  {id: 'foot', name: 'Foot', execString: 'foot', categories: ['TerminalEmulator']},
  {id: 'btop', name: 'btop', execString: 'btop'},
  {id: 'yazi', name: 'yazi', execString: 'yazi'}
];
const pinned = ['foot', 'btop', 'yazi'];

// The module runs in a vm realm with its own Date; mock the realm's clock.
const vm = require('node:vm');
const vmDate = vm.runInContext('Date', matcher);
const realVmNow = vmDate.now;
function withVmTime(offsetMs, fn) {
  const base = realVmNow();
  vmDate.now = () => base + offsetMs;
  try { return fn(); } finally { vmDate.now = realVmNow; }
}

function windowsByApp(toplevels) {
  const items = matcher.buildDockItems(pinned, toplevels, null, entries, null, {}, {}, 20, []);
  const byApp = {};
  for (const item of items) {
    // Array.from: item.toplevels lives in the vm realm and would fail deepStrictEqual
    byApp[item.appId] = Array.from(item.toplevels, t => t.address);
  }
  return byApp;
}

// --- Scanner attribution is per-window, not global -------------------------
const btopWin = {appId: 'foot', title: 'low priority', address: '0x1'};
const shellWin = {appId: 'foot', title: 'pi@fred: ~', address: '0x2'};

// A flat list cannot name its window; the scanner reports address/app pairs.
matcher.setDetectedCliApps([{address: '0x1', app: 'btop'}]);
let byApp = windowsByApp([btopWin, shellWin]);
assert.deepEqual(byApp['btop'], ['0x1'], 'scanner result names its own window');
assert.deepEqual(byApp['foot'], ['0x2'], 'an unrelated shell stays with the terminal');

// Per-window evidence survives scanner expiry via the sticky cache.
byApp = withVmTime(16000, () => windowsByApp([btopWin, shellWin]));
assert.deepEqual(byApp['btop'], ['0x1'], 'confirmed attribution survives scanner expiry');
assert.deepEqual(byApp['foot'], ['0x2']);

// Legacy flat lists without addresses attribute nothing rather than everything.
matcher.setDetectedCliApps(['yazi']);
byApp = windowsByApp([{appId: 'foot', title: 'pi@fred: ~', address: '0x3'}]);
assert.deepEqual(byApp['foot'], ['0x3'], 'address-less scanner entries are ignored');
assert.ok(!byApp['yazi'] || byApp['yazi'].length === 0, 'no window is guessed');

// --- A launch hint must not stick to an unrelated terminal ------------------
{
  const hintShell = {appId: 'foot', title: 'pi@fred: ~', address: '0x9'};
  const toplevels = [hintShell];
  matcher.setPendingCliHint('btop', []);
  byApp = windowsByApp(toplevels);
  assert.deepEqual(byApp['btop'], ['0x9'], 'hint gives instant identity while valid');

  byApp = withVmTime(8000, () => windowsByApp(toplevels)); // hint expires after 6s
  assert.deepEqual(byApp['foot'], ['0x9'], 'expired hint releases the window');
  assert.ok(!byApp['btop'] || byApp['btop'].length === 0, 'hint guess never becomes sticky');
}

// --- Title evidence still sticks (cliamp marquee contract) ------------------
{
  const cliWin = {appId: 'foot', title: 'yazi - ~/Downloads', address: '0x4'};
  const toplevels = [cliWin];
  byApp = windowsByApp(toplevels);
  assert.deepEqual(byApp['yazi'], ['0x4']);
  byApp = windowsByApp([{appId: 'foot', title: 'pi@fred: ~', address: '0x4'}]);
  // Same window object retains its identity once the title no longer says it.
  assert.deepEqual(windowsByApp(toplevels)['yazi'], ['0x4'], 'title evidence sticks');
}

console.log('CLI attribution: per-window scanner mapping and non-sticky launch hints passed.');
