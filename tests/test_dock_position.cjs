const assert = require('node:assert/strict');
const loadJS = require('./helpers/load-js.cjs');
const settings = loadJS('DockSettings.js');
const geometry = loadJS('DockGeometry.js');
const edges = ['top', 'bottom', 'left', 'right'];
const opposite = {top: 'bottom', bottom: 'top', left: 'right', right: 'left'};
let cases = 0;
for (const profile of ['general', 'windows', 'mac']) {
  for (const bar of edges) {
    for (const position of ['auto', 'bottom', 'left', 'right']) {
      const requested = position === 'auto' ? (profile === 'general' ? opposite[bar] : 'bottom') : position;
      const edge = requested === bar ? opposite[bar] : requested;
      assert.equal(settings.resolveDockPosition(position, profile, bar), edge);
      const dock = geometry.panelLayout(edge, 5, false);
      const vertical = edge === 'left' || edge === 'right';
      assert.equal(dock.vertical, vertical);
      for (const side of edges) {
        assert.equal(dock.anchors[side], side === edge);
        assert.equal(dock.margins[side], side === edge ? 5 : 0);
      }
      for (const taskbar of [false, true]) {
        for (const overlay of [false, true]) {
          for (const ignoreDockExclusion of [false, true]) {
            const popup = geometry.popupLayout({edge, slotSize: 42, gap: 5, taskbar, taskbarSize: 32, overlay, ignoreDockExclusion});
            assert.equal(popup.vertical, vertical);
            const expectedOffset = taskbar ? (ignoreDockExclusion ? 32 : 36) : (overlay || ignoreDockExclusion ? 60 : 5);
            assert.equal(popup.offset, expectedOffset);
            assert.equal(popup.ignoreExclusion, taskbar || overlay || ignoreDockExclusion);
            for (const side of edges) {
              assert.equal(popup.anchors[side], side === edge || (vertical ? ['top', 'bottom'] : ['left', 'right']).includes(side));
              assert.equal(popup.margins[side], side === edge ? expectedOffset : 0);
            }
          }
        }
      }
      cases++;
    }
  }
}
assert.deepEqual(JSON.parse(JSON.stringify(geometry.surfaceSize(false, 42, 400))), {width: 408, height: 46});
assert.deepEqual(JSON.parse(JSON.stringify(geometry.surfaceSize(true, 42, 400))), {width: 46, height: 408});
assert.equal(geometry.surfaceSize(false, 42, 0).width, 46, 'empty docks keep their minimum size');
const base = {vertical: false, width: 1000, height: 1000, dockLength: 400, itemOffset: 100, cardWidth: 260, cardHeight: 180, taskbarAnchor: null};
assert.equal(geometry.appMenuPosition(base).x, 270, 'app offset includes its left widgets');
assert.equal(geometry.appMenuPosition(base).y, 0);
assert.equal(geometry.appMenuPosition({...base, vertical: true}).y, 310);
assert.equal(geometry.appMenuPosition({...base, taskbarAnchor: 10}).x, 6, 'clamp to screen start');
assert.equal(geometry.appMenuPosition({...base, taskbarAnchor: 990}).x, 734, 'clamp to screen end');
assert.equal(geometry.appMenuPosition({...base, taskbarAnchor: 600}).x, 470, 'taskbar uses its actual icon anchor');
console.log(`${cases} placement combinations plus popup exclusions, sizes and menu bounds passed.`);
