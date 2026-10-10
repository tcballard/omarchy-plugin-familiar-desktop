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

// Real RSS panel identity: registered name + shared Quickshell app ID. Keep
// the original windows and separate other shell panels and standalone Qt apps.
const panels = loadJS('PluginPanels.js');
const panelEntries = panels.entriesFor({
  'io.github.tcballard.rss-feed': {metadata: {displayName: 'RSS Feed', pluginId: 'io.github.tcballard.rss-feed'}},
  'omarchy.agents': {metadata: {displayName: 'Agents'}},
  'example.panel': {metadata: {displayName: 'Example Panel', icon: 'file:///tmp/example.svg'}},
}, id => id === 'io.github.tcballard.rss-feed' ? '\uf09e' : '\udb81\udeb8');
assert.equal(panelEntries[0].iconGlyph, '\uf09e');
assert.equal(panelEntries[2].iconGlyph, '', 'image assets are not font glyphs');
const rss = {appId: 'org.quickshell', title: 'RSS Feed', address: '0xrss'};
const rssOther = {appId: 'org.quickshell', title: 'RSS Feed', address: '0xrss2', minimized: true};
const agents = {appId: 'org.quickshell', title: 'Agents', address: '0xagents'};
const unknown = {appId: 'org.quickshell', title: 'Unregistered panel', address: '0xunknown'};
const nativeQt = {appId: 'org.kde.example', title: 'RSS Feed', address: '0xnative'};
const panelWindows = [rss, rssOther, agents, unknown, nativeQt];
assert.equal(panels.resolve(nativeQt, panelEntries), null, 'standalone Qt apps keep their own identity');
assert.equal(panels.resolve(unknown, panelEntries), null);
assert.equal(panels.resolve(rss, panelEntries.concat([{id: 'duplicate', name: 'RSS Feed'}])), null, 'ambiguous titles are not guessed');
const nativeEntry = {id: 'org.kde.example', name: 'Native Qt app', icon: 'native-example'};
for (const pins of [[], ['io.github.tcballard.rss-feed'], ['org.quickshell'], [{isStack: true, id: 'panels', apps: ['io.github.tcballard.rss-feed']}]] ) {
  const items = matcher.buildDockItems(pins, panelWindows, rss, [nativeEntry], null, {}, {}, 0, [], [], panelEntries);
  const apps = items.flatMap(item => item.isStack ? Array.from(item.subApps) : [item]);
  const rssApp = apps.find(item => item.appId === 'io.github.tcballard.rss-feed');
  assert.equal(rssApp.iconGlyph, '\uf09e');
  assert.equal(rssApp.pluginId, 'io.github.tcballard.rss-feed');
  assert.equal(rssApp.windowCount, 2);
  assert.equal(rssApp.toplevels[0], rss);
  assert.equal(rssApp.toplevels[1], rssOther);
  assert.equal(rssApp.isActive, true);
  assert.equal(apps.find(item => item.appId === 'omarchy.agents').windowCount, 1);
  assert.equal(apps.find(item => item.appId === 'org.quickshell').windowCount, 1, 'generic shell pin collects only unmatched windows');
  assert.equal(apps.find(item => item.appId === 'org.kde.example').iconGlyph, '');
}
const pinnedClosed = matcher.buildDockItems(['io.github.tcballard.rss-feed'], [], null, [], null, {}, {}, 0, [], [], panelEntries)[0];
assert.equal(pinnedClosed.iconGlyph, '\uf09e');
assert.equal(pinnedClosed.isRunning, false);
const launch = loadJS('DockLauncher.js');
let command = [], ordinaryLaunches = 0;
launch.launchApp({summon: () => false, appLibrary: {launch: () => ordinaryLaunches++}}, pinnedClosed, {execArgv: argv => {command = Array.from(argv);}});
assert.deepEqual(command, ['omarchy-shell', 'shell', 'summon', 'io.github.tcballard.rss-feed', '{}'], 'closed plugin pins use the existing widget-slot command route');
assert.equal(ordinaryLaunches, 0);
console.log('Registered panel glyphs, distinct shared-shell windows, native Qt identity, pins/folders and panel relaunch: passed.');
