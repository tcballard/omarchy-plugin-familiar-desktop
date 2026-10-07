// Optional native FileView smoke test. Run on a development host with Quickshell;
// it starts only an offscreen, isolated state fixture, never another desktop.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {spawnSync} = require('node:child_process');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'familiar-coach-store-'));
const statePath = path.join(dir, 'progress.json');
const moduleUrl = JSON.stringify(pathToFileURL(path.resolve('components')).href);
const coachUrl = JSON.stringify(pathToFileURL(path.resolve('ShortcutCoach.js')).href);
const saved = {schemaVersion: 1, enabled: false, lastHintAt: 1000000,
  lessons: {closeWindow: {hintsShown: 2, learned: true, skipped: false, lastShownAt: 1000000}}};
function run(mode) {
  const file = path.join(dir, 'shell.qml');
  fs.writeFileSync(file, `
import QtQuick
import Quickshell
import ${moduleUrl}
import ${coachUrl} as Coach
ShellRoot {
    id: test
    property bool started: false
    property string mode: ${JSON.stringify(mode)}
    ShortcutCoachStore {
        id: store
        path: ${JSON.stringify(statePath)}
        onReadyChanged: if (ready) Qt.callLater(test.exercise)
    }
    function exercise() {
        if (started) return
        started = true
        if (mode === "write") store.update(${JSON.stringify(saved)})
        if (mode === "reset") store.update(Coach.normalize({enabled: store.learningState.enabled}))
    }
    Timer {
        interval: 20; running: true; repeat: true
        onTriggered: {
            if (!test.started || store.saving) return
            console.log("COACH_STATE=" + JSON.stringify(store.learningState))
            console.log("COACH_WRITABLE=" + store.writable)
            Qt.quit()
        }
    }
}
`);
  const result = spawnSync('quickshell', ['-p', file], {
    encoding: 'utf8', timeout: 15000,
    env: {...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'}
  });
  if (result.error) throw result.error;
  const output = result.stdout + result.stderr;
  assert.equal(result.status, 0, output);
  const match = output.match(/COACH_STATE=(\{[^\n]*\})/);
  assert.ok(match, output);
  return {state: JSON.parse(match[1]), writable: output.includes('COACH_WRITABLE=true')};
}
try {
  assert.deepEqual(run('read').state.lessons, {}); // Missing file.
  assert.deepEqual(run('write').state, saved);
  assert.deepEqual(JSON.parse(fs.readFileSync(statePath, 'utf8')), saved);
  assert.deepEqual(run('read').state, saved); // Separate native shell process.
  assert.equal(run('reset').state.enabled, false);
  assert.deepEqual(run('read').state.lessons, {});
  fs.writeFileSync(statePath, '{broken');
  assert.deepEqual(run('read').state.lessons, {});
  fs.writeFileSync(statePath, '{"schemaVersion":99}');
  assert.equal(run('write').writable, false);
  assert.equal(fs.readFileSync(statePath, 'utf8'), '{"schemaVersion":99}');
  console.log('Native Shortcut Coach atomic file writes, process restart, reset and corrupt/future state: passed');
  if (process.env.WAYLAND_DISPLAY) {
    // Resolve real PanelWindow/layershell types without showing a surface or
    // taking focus. qmllint lacks the platform-provided PanelWindow metadata.
    fs.mkdirSync(path.join(dir, 'qs'), {recursive: true});
    fs.cpSync('tests/imports/qs/Commons', path.join(dir, 'qs/Commons'), {recursive: true});
    fs.writeFileSync(path.join(dir, 'shell.qml'), `
import QtQuick
import Quickshell
import ${moduleUrl}
ShellRoot {
    QtObject {
        id: coach
        property var activeLesson: null
        property string labelStyle: "standard"
        function dismiss() {}
        function markLearned(id) {}
    }
    ShortcutCoachToast { controller: coach }
    Timer {
        interval: 100; running: true
        onTriggered: { console.log("COACH_PANEL_LOADED"); Qt.quit() }
    }
}
`);
    const panel = spawnSync('quickshell', ['-p', path.join(dir, 'shell.qml')], {
      encoding: 'utf8', timeout: 15000,
      env: {...process.env, QT_QPA_PLATFORM: 'wayland', QML_IMPORT_PATH: dir}
    });
    if (panel.error) throw panel.error;
    assert.equal(panel.status, 0, panel.stdout + panel.stderr);
    assert.match(panel.stdout + panel.stderr, /COACH_PANEL_LOADED/);
    console.log('Native hidden coach PanelWindow/layershell component load: passed');
  }
} finally {
  fs.rmSync(dir, {recursive: true, force: true});
}
