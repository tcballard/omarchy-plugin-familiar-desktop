// Execute the production placement policy and surface anchor expressions.
// This catches reversed side menus without pretending to run a compositor.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const settings = vm.createContext({});
vm.runInContext(fs.readFileSync('DockSettings.js', 'utf8').replace(/^\.pragma library\s*/, ''), settings);
const panel = fs.readFileSync('DockPanel.qml', 'utf8');
const positionBinding = panel.match(/readonly property string dockScreenPosition: ([\s\S]*?)\n    readonly property/)[1];
const originBinding = panel.match(/readonly property string barPosition: (.*)/)[1];
const verticalBinding = panel.match(/readonly property bool isVertical: (.*)/)[1];
const surfaces = [
  { name: 'dock', source: panel.slice(panel.indexOf('id: dockLayer')) },
  { name: 'hover strip', source: panel.slice(panel.indexOf('id: edgeTriggerWindow')) },
  ...['AppMenu', 'FolderMenu', 'FolderPopup'].map(name => ({ name, source: fs.readFileSync(`components/${name}.qml`, 'utf8') }))
];
const edges = ['top', 'bottom', 'left', 'right'];
const opposite = { top: 'bottom', bottom: 'top', left: 'right', right: 'left' };
let cases = 0;
for (const profile of ['general', 'windows', 'mac']) {
  for (const bar of edges) {
    for (const position of ['auto', 'bottom', 'left', 'right']) {
      const requested = position === 'auto' ? (profile === 'general' ? opposite[bar] : 'bottom') : position;
      const expected = requested === bar ? opposite[bar] : requested;
      const root = { profile, dockPosition: position, systemBarPosition: bar, taskbarActive: false };
      const context = { root, DockSettings: settings };
      root.dockScreenPosition = vm.runInNewContext(positionBinding, context);
      context.dockScreenPosition = root.dockScreenPosition;
      root.barPosition = vm.runInNewContext(originBinding, context);
      root.isVertical = vm.runInNewContext(verticalBinding, context);
      assert.equal(root.dockScreenPosition, expected);
      assert.equal(root.isVertical, ['left', 'right'].includes(expected));
      for (const surface of surfaces) {
        const block = surface.source.match(/anchors \{([\s\S]*?)\n\s*\}/)[1];
        const env = { root, menuWindow: { root }, stackWindow: { root } };
        const anchored = {};
        for (const edge of edges) {
          const expression = block.match(new RegExp(`\\b${edge}:\\s*([^\\n]+)`))[1];
          anchored[edge] = vm.runInNewContext(expression, env);
        }
        assert.equal(anchored[expected], true, `${surface.name}: anchor ${expected}`);
        assert.equal(anchored[opposite[expected]], false, `${surface.name}: keep inward edge free`);
        if (surface.name !== 'dock' && surface.name !== 'hover strip') {
          const margins = surface.source.match(/margins \{([\s\S]*?)\n\s*\}/)[1];
          const offsets = { ...env, dockOffset: 60, isDirectDockPopup: true, isOverlay: false, stackOffset: 180 };
          root.slotSize = 42;
          offsets.Style = { gapsOut: 5 };
          // FolderMenu uses multiline margins; evaluate up to the next edge.
          for (const edge of edges) {
            const expression = margins.match(new RegExp(`\\b${edge}:([\\s\\S]*?)(?=\\n\\s*(?:top|bottom|left|right):|$)`))[1].trim();
            const margin = vm.runInNewContext(expression, offsets);
            assert.equal(margin > 0, edge === expected, `${surface.name}: inward offset from ${expected}`);
          }
        }
      }
      cases++;
    }
  }
}
console.log(`${cases} placement combinations: dock, hover strip and three popup anchors passed`);
