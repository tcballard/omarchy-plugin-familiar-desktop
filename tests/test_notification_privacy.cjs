const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const Identity = require('./helpers/load-js.cjs')('AppIdentity.js');
const source = fs.readFileSync('components/NotificationTracker.qml', 'utf8');
const context = { Identity, notificationCounts: {}, titleExtractedBadges: {}, canonicalCounts: {}, canonicalUrgent: {}, lastNotifTimestamps: {},
  badgeChanged() {}, scheduleSave() {}, rebuildSnapshot() {}, isAppCurrentlyActive() { return false; } };
context.tracker = context;
vm.createContext(context);
for (const name of ['toCanonical', 'refreshCounts', 'incrementBadge', 'snapshotKey', 'processIncomingNotification']) {
  const start = source.indexOf(`    function ${name}(`);
  const end = source.indexOf('\n    }', start) + 6;
  vm.runInContext(source.slice(start, end), context);
}
const secret = 'Private appointment 8675309';
context.processIncomingNotification({app: 'chromium', summary: secret, urgency: 2});
assert.equal(context.canonicalCounts.chrome, 1);
assert.equal(context.canonicalUrgent.chrome, true);
assert.equal(Object.keys(context.canonicalCounts).length, 2);
context.processIncomingNotification({summary: secret});
assert.equal(Object.keys(context.canonicalCounts).length, 2);
context.processIncomingNotification({app: 'org.telegram.desktop', summary: secret});
assert.equal(context.canonicalCounts.telegram, 1);
assert.doesNotMatch(JSON.stringify(context.canonicalCounts), /8675309|appointment/i);
// Exercise the actual save handler with legacy sensitive state as well.
context.notificationCounts = {[secret]: 2};
context.persisted = {};
context.saveProc = {running: false};
context.saveDebounceTimer = {restart() { throw new Error('unexpected retry'); }};
context.Qt = {resolvedUrl() { return 'file:///plugin/bin/familiar-desktop'; }};
const start = source.indexOf('        onTriggered: {') + '        onTriggered: {'.length;
const end = source.indexOf('\n        }', start);
vm.runInContext('(function() {' + source.slice(start, end) + '})()', context);
assert.deepEqual(Array.from(context.saveProc.command), ['/plugin/bin/familiar-desktop', 'badges', 'save', '--stdin']);
assert.equal(context.saveProc.stdinEnabled, true);
assert.equal(JSON.parse(context.saveProc.payload).counts[secret], 2);
let piped;
context.payload = context.saveProc.payload;
context.write = value => { piped = value; };
const started = source.indexOf('        onStarted: {') + '        onStarted: {'.length;
vm.runInContext(source.slice(started, source.indexOf('\n        }', started)), context);
assert.equal(JSON.parse(piped).counts[secret], 2);
assert.equal(context.stdinEnabled, false);
assert.equal(context.payload, '');
console.log('notification identity and private badge transport: passed');
