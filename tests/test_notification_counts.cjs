const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('components/NotificationTracker.qml', 'utf8');
function tracker(disk = {counts: {}, urgent: {}}, persisted = {}) {
  const state = {
    notificationCounts: {}, canonicalCounts: {}, canonicalUrgent: {}, titleExtractedBadges: {},
    lastNotifTimestamps: {}, knownWindows: [], previouslyOpenAppKeys: [], persisted,
    ToplevelManager: {activeToplevel: null}, badgeChanged() {},
    badgeStateFile: {text() { return JSON.stringify(disk); }},
    saveDebounceTimer: {restart() {}}, saveProc: {running: false},
    Qt: {resolvedUrl() { return 'file:///plugin/bin/familiar-desktop'; }}
  };
  state.tracker = state;
  vm.createContext(state);
  for (const name of ['toCanonical', 'refreshCounts', 'incrementBadge', 'clearBadge',
    'clearByRawIdentifier', 'clearBadgeKeys', 'isAppCurrentlyActive', 'extractUnreadFromTitle',
    'syncWindowTitles', 'updateOpenWindowsAndClearClosed', 'loadDiskState', 'scheduleSave']) {
    const start = source.indexOf(`    function ${name}(`);
    assert.notEqual(start, -1, name);
    vm.runInContext(source.slice(start, source.indexOf('\n    }', start) + 6), state);
  }
  return state;
}
const plain = value => JSON.parse(JSON.stringify(value));
const t = tracker();
const browser = {appId: 'chromium', title: '(3) Inbox'};
const webapp = {appId: 'chrome-web.whatsapp.com__-Default', title: '(4) Chat'};
t.knownWindows = [browser, webapp];
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, 3);
assert.equal(t.canonicalCounts.whatsapp, 4);
browser.title = '(1) Inbox';
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, 1);
browser.title = 'Inbox';
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, undefined);
assert.equal(t.canonicalCounts.whatsapp, 4, 'one app cannot erase another');

browser.title = '(3) Inbox';
t.syncWindowTitles();
t.incrementBadge('chromium', 1, true);
assert.equal(t.notificationCounts.chrome, 1, 'events must not increment the title total');
assert.equal(t.canonicalCounts.chrome, 3, 'sources combine by max, not addition');
browser.title = 'Inbox';
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, 1, 'title removal must retain independent notifications');
assert.equal(t.canonicalUrgent.chrome, true);
t.clearByRawIdentifier('chrome');
assert.equal(t.canonicalCounts.chromium, undefined, 'clearing canonical identity removes event aliases');
assert.equal(t.canonicalUrgent.chrome, undefined);

browser.title = '(3) Inbox';
const second = {appId: 'chromium', title: '[5] Other inbox'};
t.knownWindows.push(second);
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, 5);
second.title = '[2] Other inbox';
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, 3, 'multiple titles use current maximum');
t.ToplevelManager.activeToplevel = browser;
t.clearBadge({appId: 'chromium'});
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, undefined, 'focused app remains cleared');
t.ToplevelManager.activeToplevel = null;
t.syncWindowTitles();
assert.equal(t.canonicalCounts.chrome, 3, 'unfocused title reflects current unread state');
t.knownWindows = [];
t.syncWindowTitles();
assert.deepEqual(plain(t.canonicalCounts), {}, 'empty window list removes title-only badges');

const closing = tracker();
closing.knownWindows = [browser];
closing.updateOpenWindowsAndClearClosed(closing.knownWindows);
closing.incrementBadge('chromium', 1, true);
closing.knownWindows = [];
closing.updateOpenWindowsAndClearClosed([]);
assert.deepEqual(plain(closing.canonicalCounts), {}, 'existing last-window-close policy clears both sources');
assert.deepEqual(plain(closing.canonicalUrgent), {});

const legacy = tracker({counts: {chrome: 7}, urgent: {chrome: true}});
legacy.loadDiskState();
assert.equal(legacy.canonicalCounts.chrome, 7, 'legacy counts are preserved until normal acknowledgement');
legacy.clearByRawIdentifier('chromium');
legacy.loadDiskState();
assert.deepEqual(plain(legacy.canonicalCounts), {}, 'empty persistent state must not resurrect old disk counts');
const reloaded = tracker({counts: {chrome: 7}, urgent: {}}, legacy.persisted);
reloaded.loadDiskState();
assert.deepEqual(plain(reloaded.canonicalCounts), {}, 'reload preserves acknowledged empty state');

const saved = tracker();
saved.knownWindows = [browser];
saved.syncWindowTitles();
saved.incrementBadge('chromium', 1, false);
const start = source.indexOf('        onTriggered: {') + '        onTriggered: {'.length;
vm.runInContext('(function() {' + source.slice(start, source.indexOf('\n        }', start)) + '})()', saved);
const snapshot = JSON.parse(saved.saveProc.payload);
assert.equal(snapshot.counts.chrome, 1, 'only event contribution is persisted');
assert.doesNotMatch(saved.saveProc.payload, /Inbox/);
const restarted = tracker(snapshot);
restarted.loadDiskState();
assert.equal(restarted.canonicalCounts.chrome, 1, 'title-only peak must not become a persisted event');
assert.deepEqual(plain(restarted.titleExtractedBadges), {});
console.log('title decreases, event independence, focus/close and persistence: passed');
