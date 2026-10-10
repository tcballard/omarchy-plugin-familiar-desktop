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
assert.equal(icons.resolve('https://example.org/icon.svg', lookup), 'https://example.org/icon.svg');
assert.equal(icons.resolve('Unknown', lookup), '');
assert.equal(icons.resolve('Unknown', {...lookup, friendlyFallback: true}), 'file:///usr/share/pixmaps/omarchy.png');
assert.equal(icons.resolve('Custom', {...lookup, diskIcon: name => name === 'custom' ? 'file:///disk.svg' : '', library: {iconSource: () => 'theme://library'}}), 'file:///disk.svg');
assert.equal(icons.resolve('Unknown', {...lookup, library: {iconSource: () => 'image://application-x-executable'}, iconPath: name => name === 'unknown' ? 'theme://unknown' : ''}), 'theme://unknown');
console.log('Shared app identity, launch IDs, icon priority and fallbacks: passed');
