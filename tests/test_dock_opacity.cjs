// Exercise production settings APIs; DockAppearance's Qt tests cover the colors.
const assert = require('node:assert/strict');
const loadJS = require('./helpers/load-js.cjs');
const DockSettings = loadJS('DockSettings.js');
for (const value of [undefined, null, true, false, '', ' ', 'banana', -1, 101, NaN, Infinity, '0.5', 0.5, {}, []])
  assert.equal(DockSettings.normalize({dockBackgroundOpacity:value}).dockBackgroundOpacity, 'theme');
assert.equal(DockSettings.normalize({}).dockBackgroundOpacity, 'theme', 'old settings follow theme');
const schema = loadJS('components/SettingsSchema.js');
for (const choice of ['0','25','50','75','100','theme']) {
  const loaded = schema.normalize({dockBackgroundOpacity:choice,dockWidgets:['omarchy.apps']});
  const saved = JSON.parse(schema.encode({future:1},{...loaded,showBadges:false}));
  assert.equal(saved.dockBackgroundOpacity,choice);
  assert.equal(schema.normalize(saved).dockBackgroundOpacity,choice);
}
console.log('Dock opacity: malformed settings and shared persistence passed');
