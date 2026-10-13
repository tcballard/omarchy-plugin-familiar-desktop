const assert = require('node:assert/strict');
const load = require('./helpers/load-js.cjs');
const identity = load('AppIdentity.js');
const model = load('DockModel.js');
const icons = load('IconResolver.js');
for (const [input, expected] of [
  ['transmission-gtk', 'transmission'], ['com.transmissionbt.Transmission.desktop', 'transmission'],
  ['ru.yandex.desktop.browser', 'yandex-browser'], ['yandex-mail', 'yandexmail'],
  ['https://google.com/photos', 'photos'], ['chrome-youtube.com__-Default', 'youtube'],
  ['chrome-maps.google.com__-Default', 'maps'], ['chromium', 'chrome'],
  ['org.telegram.desktop', 'telegram'], ['', ''], [null, '']
]) {
  assert.equal(identity.toCanonical(input), expected, input);
  assert.equal(model.toCanonical(input), expected, `dock identity: ${input}`);
}
const pins = ['chrome-youtube.com__-Default', 'chrome-maps.google.com__-Default'];
assert.deepEqual(Array.from(model.parsePinned(JSON.stringify(pins))), pins, 'grouping never replaces launch IDs');
const lookup = {candidates: model.getCandidates, diskIcon: () => '', library: null, iconPath: () => '', friendlyFallback: false};
assert.equal(icons.resolve('/tmp/my-icon.png', lookup), 'file:///tmp/my-icon.png');
assert.equal(icons.resolve('https://example.org/icon.svg', lookup), 'file:///usr/share/pixmaps/omarchy.png');
assert.equal(icons.resolve('Unknown', lookup), 'file:///usr/share/pixmaps/omarchy.png');
assert.equal(icons.resolve('Unknown', {...lookup, friendlyFallback: true}), 'file:///usr/share/pixmaps/omarchy.png');
assert.equal(icons.resolve('Custom', {...lookup, diskIcon: name => name === 'custom' ? 'file:///disk.svg' : '', library: {iconSource: () => 'theme://library'}}), 'file:///disk.svg');
assert.equal(icons.resolve('Unknown', {...lookup, library: {iconSource: () => 'image://application-x-executable'}, iconPath: name => name === 'unknown' ? 'image://theme/unknown' : ''}), 'image://theme/unknown');

const generic = 'file:///usr/share/pixmaps/omarchy.png';
const foreignIds = ['https://example.org/huge.png', 'HTTP://127.0.0.1/huge', '//example.org/icon',
  'file:///tmp/client.png', '/tmp/client.png', 'image://client/icon', 'qrc:/client.svg',
  'data:image/svg+xml,large', 'ftp://example.org/icon', 'https:example.org'];
for (const appId of foreignIds) {
  const top = {appId, title: 'Foreign client'};
  for (const pins of [[], [appId], [{isStack: true, id: 'folder', apps: [appId]}]]) {
    const items = model.buildDockItems(pins, [top], top, [], null, {}, {}, 0, []);
    const app = items[0].isStack ? items[0].subApps[0] : items[0];
    assert.equal(app.isRunning, true, appId);
    assert.equal(app.appId, appId, 'retain window identity');
    assert.equal(app.iconIdentifierOnly, true);
    assert.equal(app.icon, generic, 'matcher never promotes foreign IDs to sources');
    const noLookup = {...lookup, friendlyFallback: true,
      candidates: () => {throw new Error('unsafe app ID reached lookup');}};
    assert.equal(icons.resolve(app, noLookup), generic, appId);
    assert.equal(icons.resolve({appId}, noLookup), generic, 'bare IDs stay identifiers');
  }
}
assert.equal(icons.resolve({appId: 'org.example.Native', iconIdentifierOnly: true},
  {...lookup, iconPath: name => name === 'org.example.Native' ? 'image://theme/native' : ''}), 'image://theme/native');
for (const source of ['https://example.org/icon', 'HtTp://localhost/icon', '//example.org/icon',
  'file://example.org/icon', 'data:image/png;base64,large', 'ftp://example.org/icon']) {
  assert.equal(icons.localSource(source), '', source);
  for (const field of ['rawIcon', 'icon']) assert.equal(icons.resolve({[field]: source}, lookup), generic);
  for (const method of ['diskIcon', 'iconPath']) {
    assert.equal(icons.resolve('Unknown', {...lookup, [method]: () => source}), generic);
  }
  assert.equal(icons.resolve('Unknown', {...lookup, library: {iconSource: () => source}, friendlyFallback: true}), generic);
}
for (const source of ['file:///tmp/icon.png', 'qrc:/icons/app.svg', 'image://theme/app']) {
  assert.equal(icons.localSource(source), source);
  assert.equal(icons.resolve(source, lookup), source);
}
console.log('Shared app identity, launch IDs, icon priority and fallbacks: passed');
