// Exercise production settings readers/writers and background bindings without a compositor.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function library(file) {
  const context = vm.createContext({});
  const source = fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/m, '')
    .replace(/^\.import "([^"]+)" as (\w+)\s*$/gm, (_, dependency, name) => {
      context[name] = library(dependency); return '';
    });
  vm.runInContext(source, context);
  return context;
}
const DockSettings = library('DockSettings.js');
const sources = ['BarWidget.qml', 'DockPanel.qml'].map(f => fs.readFileSync(f, 'utf8'));
const panel = sources[1];
function binding(name) {
  return panel.match(new RegExp(`readonly property (?:color|bool) ${name}: ([\\s\\S]*?)(?=\\n    (?:readonly property|//))`))[1].trim();
}
const colorBinding = binding('dockBackgroundColor');
const transparentBinding = binding('dockBackgroundTransparent');
for (const value of [undefined, null, true, false, '', ' ', 'banana', -1, 101, NaN, Infinity, '0.5', 0.5, {}, []])
  assert.equal(DockSettings.normalize({dockBackgroundOpacity:value}).dockBackgroundOpacity, 'theme');
assert.equal(DockSettings.normalize({}).dockBackgroundOpacity, 'theme', 'old settings follow theme');
const Qt = {rgba: (r,g,b,a) => ({r,g,b,a})};
const Util = {alpha: (c,a) => ({...c,a})};
for (const isBarTransparent of [true, false]) {
  for (const background of [{r:.1,g:.2,b:.3,a:1}, {r:.7,g:.6,b:.5,a:0}]) {
    for (const choice of ['theme', '0', '25', '50', '75', '100']) {
      const root = {dockBackgroundOpacity:choice,isBarTransparent};
      const context = {root,Qt,Util,Color:{bar:{background}}};
      const original = JSON.stringify(context.Color);
      const color = vm.runInNewContext(colorBinding, context);
      assert.equal(color.a, choice === 'theme' ? (isBarTransparent ? .25 : background.a) : Number(choice)/100);
      assert.equal(color.r, background.r);
      assert.equal(vm.runInNewContext(transparentBinding, context), choice === 'theme' ? isBarTransparent : Number(choice)<100);
      assert.equal(JSON.stringify(context.Color), original, 'theme must stay untouched');
    }
  }
}
const schema = require('./helpers/load-js.cjs')('components/SettingsSchema.js');
for (const choice of ['0','25','50','75','100','theme']) {
  const loaded = schema.normalize({dockBackgroundOpacity:choice,dockWidgets:['omarchy.apps']});
  const saved = JSON.parse(schema.encode({future:1},{...loaded,showBadges:false}));
  assert.equal(saved.dockBackgroundOpacity,choice);
  assert.equal(schema.normalize(saved).dockBackgroundOpacity,choice);
}
console.log('Dock opacity: theme/override matrix, malformed settings and shared persistence passed');
