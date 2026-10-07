const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const coach = {};
vm.createContext(coach);
vm.runInContext(fs.readFileSync('ShortcutCoach.js', 'utf8').replace(/^\.pragma library\s*/, ''), coach);
const plain = value => JSON.parse(JSON.stringify(value));
const binding = (description, key, extra = {}) => ({description, key, keys: `Super + ${key}`, dispatcher: '__lua', submap: '', ...extra});
const bindings = [binding('Full width', 'F'), binding('Close window', 'Q'), binding('Toggle window floating/tiling', 'T')];
const lessons = coach.catalogue(bindings);
assert.equal(lessons.length, 3);
assert.equal(lessons[1].shortcut, 'Super + Q'); // Personal remap; never guessed Super+W.
for (const flag of ['mouse', 'release', 'longPress', 'catch_all']) {
  assert.equal(coach.catalogue([binding('Close window', 'Q', {[flag]: true})]).length, 0);
}
for (const key of ['mouse:272', 'mouse_up', 'switch:on:Lid Switch', 'code:24', '']) {
  assert.equal(coach.catalogue([binding('Close window', key)]).length, 0);
}
assert.equal(coach.catalogue([binding('Close window', 'Q', {submap: 'resize'})]).length, 0);
assert.equal(coach.catalogue([binding('Close window', 'Q', {dispatcher: 'exec', arg: 'unrelated'})]).length, 0);
assert.equal(coach.catalogue([binding('Close window', 'Q', {dispatcher: 'killactive', arg: ''})]).length, 1);
assert.equal(coach.catalogue([binding('Full width', 'F', {dispatcher: 'fullscreen', arg: '0'})]).length, 0);
assert.equal(coach.catalogue([binding('Full width', 'F', {dispatcher: 'fullscreen', arg: '1'})]).length, 1);
assert.equal(coach.catalogue([bindings[1], binding('Something else', 'q')]).length, 0);
assert.equal(coach.catalogue([bindings[1], binding('', 'Q')]).length, 0);
assert.equal(coach.catalogue([bindings[1], binding('', 'Q', {submap: 'resize'})]).length, 1);
assert.equal(coach.catalogue(null).length, 0);
assert.equal(coach.catalogue([null, {}, binding('Close window', '', {keys: 5})]).length, 0);

let state = coach.normalize({});
let now = 1000000;
assert.equal(coach.eligible(lessons[0], state, now), true);
state = coach.shown(state, lessons[0].id, now);
assert.equal(state.lessons.maximizeWindow.hintsShown, 1);
assert.equal(coach.eligible(lessons[0], state, now + coach.lessonCooldown - 1), false);
assert.equal(coach.eligible(lessons[1], state, now + coach.globalCooldown - 1), false);
assert.equal(coach.eligible(lessons[1], state, now + coach.globalCooldown), true);
for (let i = 0; i < 2; i++) {
  now += coach.lessonCooldown;
  assert.equal(coach.eligible(lessons[0], state, now), true);
  state = coach.shown(state, lessons[0].id, now);
}
assert.equal(coach.eligible(lessons[0], state, now + coach.lessonCooldown), false);
assert.equal(coach.eligible(lessons[1], state, now - 1), false);
assert.equal(coach.eligible(null, state, now), false);
state = coach.learned(state, 'closeWindow');
assert.equal(coach.eligible(lessons[1], state, now + coach.lessonCooldown), false);
assert.deepEqual(plain(coach.progress(lessons, state)), {learned: 1, total: 3, fraction: 1 / 3});
assert.deepEqual(plain(coach.progress([], state)), {learned: 0, total: 0, fraction: 0});
state.lessons.toggleFloating = {skipped: true};
assert.equal(coach.progress(lessons, state).total, 2);
assert.equal(coach.eligible(lessons[2], state, now + coach.lessonCooldown), false);
state.enabled = false;
assert.equal(coach.eligible(lessons[2], state, now + coach.lessonCooldown), false);
assert.equal(coach.progress(lessons, state).learned, 1);
assert.deepEqual(plain(coach.parse(JSON.stringify(state)).state), plain(coach.normalize(state)));
assert.equal(coach.parse('{broken').state.enabled, true);
assert.equal(coach.parse('').state.enabled, true);
assert.equal(coach.parse('{"schemaVersion":99}').writable, false);
assert.deepEqual(plain(coach.normalize({lessons: {futureLesson: {learned: true, hintsShown: -3, lastShownAt: 'bad'}}}).lessons),
  {futureLesson: {learned: true, hintsShown: 0, lastShownAt: 0, skipped: false}});
assert.deepEqual(plain(coach.learned(state, 'unknown')), plain(coach.normalize(state)));

for (const action of ['minimize-instance', 'activate-instance', 'arrange-left', 'arrange-next-monitor', 'bring-here']) {
  assert.equal(coach.actionLesson({state: 'ok', action}), '');
}
assert.equal(coach.actionLesson({state: 'failed', action: 'arrange-maximize'}), '');
assert.equal(coach.actionLesson({state: 'ok', action: 'arrange-maximize'}), 'maximizeWindow');
assert.equal(coach.actionLesson({state: 'ok', action: 'arrange-maximize', wasMaximized: true}), '');
assert.equal(coach.actionLesson({state: 'ok', action: 'arrange-float', wasFloating: false}), 'toggleFloating');
assert.equal(coach.actionLesson({state: 'ok', action: 'arrange-float', wasFloating: true}), '');
assert.equal(coach.actionLesson({state: 'ok', action: 'arrange-tile', wasFloating: true}), 'toggleFloating');
assert.equal(coach.actionLesson({state: 'ok', action: 'arrange-tile', wasFloating: true, wasFullscreen: true}), '');
assert.equal(coach.actionLesson(null), '');
console.log('Shortcut Coach catalogue, eligibility, progress and state migration: passed');

// Exercise the real mouse-menu handler: the close request precedes coaching,
// and even an unexpectedly throwing coach cannot prevent menu dismissal.
const menuSource = fs.readFileSync('components/AppMenu.qml', 'utf8');
const start = menuSource.indexOf('    function action(kind) {');
const end = menuSource.indexOf('\n    }', start) + 6;
for (const failure of ['absent', 'throws', 'disabled']) {
  let closed = 0;
  let dismissed = 0;
  const context = {app: {}, canAct: true, selectedIndex: 0,
    windows: [{close() { closed++; }}], dismiss() { dismissed++; },
    root: {shortcutCoach: failure === 'absent' ? null : {
      trigger(id) {
        assert.equal(closed, 1);
        assert.equal(id, 'closeWindow');
        if (failure === 'throws') throw new Error('fixture coach failure');
        return false;
      }
    }}};
  vm.createContext(context);
  vm.runInContext(menuSource.slice(start, end), context);
  context.action('close');
  assert.equal(closed, 1);
  assert.equal(dismissed, 1);
}
console.log('Mouse close dispatch precedes coaching and survives coach failure: passed');
