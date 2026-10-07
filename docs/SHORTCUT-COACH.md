# Shortcut Coach

Shortcut Coach suggests keyboard equivalents after mouse actions have run. It
does not block the action or take keyboard focus. There is one hint at a time;
rapid actions are dropped rather than queued. Hints disappear after 12 seconds.
**Remind me later** dismisses without learning; **Got it** marks the lesson learned.
No keypresses are monitored. There is no automatic keyboard-use detection,
analytics, network transport, scoring or rewards.

## Settings and progress

Open Familiar settings → Input → Shortcut Coach. **Show keyboard shortcut hints**
defaults to on; turning it off dismisses any active hint and retains progress.
The progress bar counts learned lessons divided by currently available, enabled
lessons, including the zero-lessons case. Each available lesson also has a
**Got it** button, so it can be learned after automatic hints have stopped.
**Reset learning progress… → Confirm reset** clears learning, hint counters,
timestamps and any retained skipped state, while preserving the hints toggle
and all other Familiar preferences. **Keep progress** cancels.

## Supported actions and binding source

| Mouse action | Lesson | Omarchy's active binding description |
| --- | --- | --- |
| Title-bar maximise button or double-click; app menu → Arrange → Maximise | Maximise window | Full width |
| Title-bar close; app menu → Close selected window | Close window | Close window |
| App menu → Arrange → Make floating / Return to tiling | Floating and tiling | Toggle window floating/tiling |

The shortcut must be used with the intended window focused. Familiar's mouse menu
can act on a selected unfocused window; the hint explains the keyboard's focus
requirement. Floating/tiling hints require a real change and are suppressed if
the mouse action also clears fullscreen. An already maximised menu target does
not produce a hint. The title-bar maximise toggle teaches both maximise and
returning to the previous size.

Definitions were checked against the installed Omarchy
`default/hypr/bindings/tiling.lua` and the existing Rust window dispatchers.
Chords come from `hyprctl -j binds` through the existing `desktop shortcuts`
backend command. `ShortcutLabels.js` supplies display terminology. No chord is
hardcoded in the lesson catalogue. Binding metadata refreshes at service setup,
when settings open, and on `configreloaded`;
there is no polling or per-click file parsing.

Lua bindings expose an opaque `__lua` callback rather than the underlying action,
so V1 recognizes only the exact Omarchy descriptions above. Legacy bindings must
also match their dispatcher and argument. Arbitrary Lua cannot be introspected:
a custom binding reusing an Omarchy description for a different action must be
renamed to avoid misleading metadata. Mouse/release/long-press/catch-all bindings,
submaps, unknown modifiers, unresolved keycodes and conflicting chords are not
taught. Missing/failed metadata yields no lessons. Minimise, restore, app launch,
window selection, workspace moves, monitor moves, centring and half-screen
arrangement have no sufficiently exact metadata mapping in V1 and keep their
existing mouse behavior.

## State and code boundaries

`ShortcutCoach.js` holds the catalogue, binding matching, action-to-lesson mapping,
normalisation, eligibility and progress. `ShortcutCoachController.qml` owns one
active hint and an idle-unless-needed dismissal timer. `ShortcutCoachStore.qml`
owns the small atomic JSON file using the same FileView mechanism as other
Familiar settings. The dock service shares this controller with all bar settings
surfaces. Toast/card and progress components contain presentation only.

`~/.config/omarchy/familiar-desktop-shortcut-coach.json` contains schema version 1,
the hints toggle, a global last-hint timestamp, and per-lesson hint count, learned,
skipped and last-shown timestamp. It stores no window identity or application
content. Unknown lesson IDs survive ordinary updates; reset clears them too.
Missing/malformed state uses empty defaults. An unknown schema disables writes
and hints instead of overwriting a newer format. Save failures keep the previous
file intact and show a settings message. The single writer serializes pending
saves so an immediately learned lesson is not lost behind an earlier hint write.
There is no live external-file editor synchronization; reload Familiar after
editing this dedicated file manually. As with any local preferences, persistence
requires a writable configuration directory.

Each lesson allows at most three automatic hints, at least 24 hours apart.
A persisted two-minute global cooldown suppresses other hints across restarts.
Reset is the explicit way to start those hints again. Moving the system clock
backwards suppresses further hints until the recorded time has passed.

## Desktop verification

This runtime change requires the workflow in [WORKFLOW.md](WORKFLOW.md): build
from the exact source, retain rollback, record full source SHA, CI run/attempt and
artifact digest, then obtain Tom's explicit acceptance on the XPS. Green portable
tests alone do not authorize merge. No release or stable binary pin changes are
needed for development. A dirty working-tree build is local development evidence,
not a commit-identified CI acceptance artifact.

For a source checkout, run `bash build.sh` before reloading the plugin; keep a
copy of the previous checkout and binaries for rollback. Do not test updated QML
with an old backend. Existing window controls must reconcile with the new backend
(**Windows → Title bars → Refresh window controls**) to regenerate their mouse
commands. Do not run installer repair that downloads stable binaries over the
development build.

1. Open Input → Shortcut Coach. Confirm the supported active chords; compare
   Getting Started and your actual bindings. Switch between Super and Command
   labels under Input → Shortcuts, then return to the coach.
2. Reset and confirm. Right-click a running app, select a regular window, choose
   Arrange → Maximise. Verify the window changes first and the hint follows.
   Keep typing in a focused app when a hint appears: keyboard focus must stay there.
3. Click Remind me later. Repeated clicks must not show another hint. Perform
   different supported actions rapidly; there must never be stacked/queued hints.
   A different eligible lesson may appear after two minutes; repeat hints for the
   same lesson require 24 hours. Reset between scenarios to avoid waiting.
4. Reset, close a disposable window from the app menu, click Got it, and verify
   the learned count/bar update. Close another disposable window: no close hint.
   Repeat with the title-bar close button and maximise/double-click controls.
5. Reset; choose Make floating for a tiled window, then Return to tiling after
   another reset. Check both teach the same toggle. Reapplying the current state
   or leaving fullscreen must not teach that simple toggle.
6. Mark a lesson learned; reload Familiar, restart the shell and reboot. Reopen
   settings and check progress remains learned. Verify the dedicated JSON file
   contains the counters/timestamps and no unrelated settings changed.
7. Turn hints off. Reset while off and perform supported mouse actions: all
   actions still work and no hint appears. Turn hints back on: existing learned
   progress must remain unless deliberately reset.
8. Begin reset, choose Keep progress, and verify nothing changed. Confirm reset
   next time: counters, learned and skipped state clear; the toggle remains.
9. Exercise launch, minimise/restore, named-window focus, half-screen, centring,
   monitor move and other unsupported actions; behavior remains unchanged.
10. In a disposable profile, try absent/malformed coach JSON, an unsupported schema,
    failed metadata and an unwritable coach file. Mouse actions must still work;
    no nonsense shortcut or destructive state overwrite should appear. Restore
    that profile's file/permissions afterward. Check two monitors, scaling and
    different bar/dock positions, including narrow screens.

Portable tests cover catalogue eligibility, corrupt/old state, cooldowns,
learning, toggling, confirmed reset, save failure/serialization, metadata refresh,
Mac labels and generated title-bar action-before-coach failure handling. They use
isolated state/command fixtures and do not certify a live compositor session.

```bash
tests/run
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input tests -import tests/imports
# Optional development-host check using real FileView in separate processes:
node tests/test_shortcut_coach_store.cjs
```
