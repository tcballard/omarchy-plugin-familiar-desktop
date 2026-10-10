const assert = require('node:assert/strict');
const drag = require('./helpers/load-js.cjs')('DockDrag.js');

for (let count = 1; count <= 8; count++) {
  for (let from = 0; from < count; from++) {
    for (let to = 0; to < count; to++) {
      const order = Array.from({length: count}, (_, i) => i);
      order.splice(to, 0, order.splice(from, 1)[0]);
      for (let index = 0; index < count; index++) {
        // The moving tile follows the pointer; neighbours occupy the new order.
        assert.equal(drag.visualSlot(index, from, to), index === from ? from : order.indexOf(index));
      }
    }
  }
}
assert.equal(drag.visualSlot(2, -1, 3), 2);
assert.equal(drag.visualSlot(2, 1, -1), 2);
const target = (...args) => JSON.parse(JSON.stringify(drag.railTarget(...args)));
assert.deepEqual(target(1, 5, 42, 30, true), {index: 2, merge: true});
assert.deepEqual(target(1, 5, 42, 54, true), {index: 2, merge: false});
assert.deepEqual(target(3, 5, 42, -30, true), {index: 2, merge: true});
assert.deepEqual(target(3, 5, 42, -54, true), {index: 2, merge: false});
assert.deepEqual(target(1, 5, 42, 42, false), {index: 2, merge: false});
assert.deepEqual(target(2, 5, 42, -999, true), {index: 0, merge: false});
assert.deepEqual(target(2, 5, 42, 999, true), {index: 4, merge: false});
assert.deepEqual(target(0, 1, 64, 999, true), {index: 0, merge: false});
assert.deepEqual(target(1, 5, 64, 50, true), {index: 2, merge: true});
console.log('dock/folder neighbour ordering, rail merging and edge insertion: passed');
