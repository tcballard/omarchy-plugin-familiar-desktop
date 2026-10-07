const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('DockPanel.qml', 'utf8');
const body = source.slice(source.indexOf('    function configureHostedWidget('), source.indexOf('    // Proxy Bar context'));
const root = {loadedWidgetItems:[], shell:{}, evaluateHoverState(){}, widgetIconRevision:0};
const context = vm.createContext({root, dockBarContext:{position:'bottom'}});
vm.runInContext(body, context);
const signal = () => ({handlers:[], connect(f){this.handlers.push(f)}});
const panel = () => ({centerOnBar:true, bar:null, anchorItem:null, opened:false, openedChanged:signal()});
const eager = panel(), lazy = panel();
const widget = {bar:null, panel:eager, panelLoader:{item:null, loaded:signal()}};
const leftIcon = {x:200}, rightIcon = {x:1200};
context.configureHostedWidget(widget, 'omarchy.agents', leftIcon);
assert.equal(eager.centerOnBar, false);
assert.equal(eager.anchorItem, leftIcon);
widget.panelLoader.item = lazy;
widget.panelLoader.loaded.handlers[0]();
assert.equal(lazy.centerOnBar, false);
assert.equal(lazy.anchorItem, leftIcon);
context.configureHostedWidget(widget, 'omarchy.agents', rightIcon);
assert.equal(eager.anchorItem, rightIcon);
assert.equal(lazy.anchorItem, rightIcon);
assert.equal(root.loadedWidgetItems.length, 1);
// The panel host uses positions within a screen-spanning bar. Verify the actual
// dock bindings across orientations and differently sized outputs.
const dock = source.slice(source.indexOf('id: dockLayer'));
for (const isVertical of [false,true]) for (const screen of [{width:1920,height:1080},{width:1280,height:800}]) {
  const env = {root:{isVertical,slotSize:42},modelData:screen};
  const dimension = name => vm.runInNewContext(dock.match(new RegExp(name + ': ([^\\n]+)'))[1], env);
  assert.equal(dimension('implicitWidth'), isVertical ? 50 : screen.width);
  assert.equal(dimension('implicitHeight'), isVertical ? screen.height : 50);
}
console.log('Hosted eager/lazy panels follow clicked icons; dock spans the anchor axis');
