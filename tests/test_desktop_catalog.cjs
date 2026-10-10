const assert = require('node:assert/strict');
const loadJS = require('./helpers/load-js.cjs');
const catalog = loadJS('DesktopCatalog.js');
const matcher = loadJS('DockMatcher.js');

const entries = [
  {id: 'alias-owner', name: 'Alias Owner', icon: 'example_app', execString: 'alias-owner'},
  {id: 'example-app.desktop', name: 'Example App', execString: '/opt/example %U'},
  {id: 'example-app.desktop', name: 'Duplicate', execString: 'duplicate'},
  {id: 'syncterm.desktop', name: 'SyncTERM', exec: 'syncterm %u'},
  {id: 'transmission-gtk.desktop', name: 'Transmission', exec: 'transmission-gtk %U'},
  {id: 'ru.yandex.desktop.browser', name: 'Yandex', exec: 'yandex-browser-stable'},
  {id: 'steam_game_1700', name: 'Arx Fatalis', icon: 'steam_icon_1700', execString: 'steam steam://rungameid/1700'},
  {id: 'mail.desktop', name: 'Outlook', execString: 'chrome --app=https://outlook.office.com/mail/'},
  {id: 'photos.desktop', name: 'Photos', execString: 'omarchy-launch-webapp https://photos.google.com/'},
  {id: 'photoshop.desktop', name: 'Photoshop', execString: 'photoshop'},
];
// Quickshell list models and app-library wrappers must use exactly the same rules.
const wrapped = {length: entries.length + 1, 0: null};
entries.forEach((entry, index) => { wrapped[index + 1] = {entry}; });
const index = catalog.createIndex(wrapped);
const cases = [
  ['EXAMPLE-APP.desktop', entries[1]], ['EXAMPLE APP', entries[1]],
  ['example', entries[1]], ['SyncTERM 1.8 - Wayland', entries[3]],
  ['com.transmissionbt.transmission_54_620133', entries[4]],
  ['yandex-browser', entries[5]], ['steam_app_1700', entries[6]],
  ['chrome-outlook.office.com__mail_-Profile_1', entries[7]],
  ['chrome-photos.google.com__-Default', entries[8]],
  ['org.example.syncterm', entries[3]], ['unknown-application', null],
];
for (const [query, expected] of cases) {
  assert.equal(catalog.find(index, query), expected, query);
  assert.equal(matcher.findEntry(wrapped, query), expected, 'public lookup: ' + query);
  assert.equal(matcher.findEntryFast(matcher.createDesktopEntryIndex(wrapped), query), expected, 'indexed lookup: ' + query);
}
assert.equal(catalog.find(index, 'example-app').execString, '/opt/example %U', 'normalized identity preserves the launch command');
assert.equal(catalog.find(catalog.createIndex([]), 'btop').id, 'btop', 'known defaults work without installed entries');

let execReads = 0;
const observed = {id: 'custom.desktop', name: 'Custom App', get execString() { execReads++; return '/opt/custom'; }};
const observedIndex = catalog.createIndex([observed]);
const readsAfterNormalization = execReads;
for (const query of ['custom', 'CUSTOM APP', 'org.example.custom', 'unmatched', 'custom']) catalog.find(observedIndex, query);
assert.equal(execReads, readsAfterNormalization, 'lookups reuse normalized metadata');
assert.equal(catalog.recordFor(observedIndex, observed), observedIndex.records[0]);

const top = {appId: 'example-app', title: 'Example', address: '0xa'};
for (const pins of [['example-app'], [], [{isStack: true, id: 'work', apps: ['example-app']}]] ) {
  const items = matcher.buildDockItems(pins, [top], top, wrapped, null, {'example-app': 2}, {}, 10, []);
  const app = items[0].isStack ? items[0].subApps[0] : items[0];
  assert.equal(app.desktopId, 'example-app.desktop');
  assert.equal(app.exec, '/opt/example %U');
  assert.equal(app.windowCount, 1);
  assert.equal(app.toplevels[0], top, 'window identity survives normalization');
  assert.equal(app.isActive, true);
  assert.equal(app.badgeCount, 2);
}
console.log('Desktop catalog: unified lookup, wrappers, precedence, compatibility and normalized metadata passed.');
