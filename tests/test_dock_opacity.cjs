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
// Use the full production methods, so a missing field in either writer fails.
for (const source of sources) {
  const read = source.slice(source.indexOf('  function readSettings()'), source.indexOf('  function saveSettings()'));
  const saveStart = source.indexOf('  function saveSettings()');
  const nextFunction = source.indexOf('  function ', saveStart + 10);
  const save = source.slice(saveStart, nextFunction);
  let stored = JSON.stringify({dockBackgroundOpacity:'0',dockWidgets:['omarchy.apps']});
  const root = {isSavingSettings:false};
  const context = vm.createContext({root,DockSettings,ShortcutLabels:library('ShortcutLabels.js'),
    DockWidgets:library('DockWidgets.js'),DockModel:library('DockModel.js'),
    settingsFile:{text:()=>stored,setText:text=>{stored=text;}},saveSettingsTimer:{restart(){}}});
  vm.runInContext(read + '\n' + save, context);
  for (const choice of ['0', '25', '50', '75', '100', 'theme']) {
    stored = JSON.stringify({dockBackgroundOpacity:choice,dockWidgets:['omarchy.apps']});
    root.isSavingSettings = false;
    context.readSettings();
    assert.equal(root.dockBackgroundOpacity,choice);
    root.showBadges = false; // an unrelated setting must not reset the override
    context.saveSettings();
    assert.equal(JSON.parse(stored).dockBackgroundOpacity,choice);
    root.dockBackgroundOpacity = 'lost-on-restart';
    root.isSavingSettings = false;
    context.readSettings();
    assert.equal(root.dockBackgroundOpacity,choice);
  }
}
console.log('Dock opacity: theme/override matrix, malformed settings and both persistence paths passed');
