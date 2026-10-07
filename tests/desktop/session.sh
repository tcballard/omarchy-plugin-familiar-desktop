#!/usr/bin/env bash
# This intentionally cannot run against a developer's normal desktop.
set -Eeuo pipefail
[[ ${FAMILIAR_DISPOSABLE_SMOKE:-} == 1 && $HOME == /home/familiar-smoke && $(id -un) == familiar-smoke ]] || {
  echo 'Requires the disposable CI account, not a personal desktop.' >&2; exit 2;
}
: "${SMOKE_ROOT:?}" "${SOURCE_SHA:?}" "${OMARCHY_SHA:?}"
export XDG_RUNTIME_DIR="$HOME/runtime"
export OMARCHY_PATH="$SMOKE_ROOT/upstream-omarchy"
export PATH="$OMARCHY_PATH/bin:$PATH"
export XDG_CURRENT_DESKTOP=Hyprland LIBGL_ALWAYS_SOFTWARE=1 QT_QPA_PLATFORM=wayland
export QS_DISABLE_FILE_WATCHER=1 QS_NO_RELOAD_POPUP=1
export EVIDENCE="$SMOKE_ROOT/smoke-evidence"
mkdir -p "$XDG_RUNTIME_DIR" "$HOME/.config/hypr" "$HOME/.config/omarchy/current" "$HOME/.local/state"
chmod 700 "$XDG_RUNTIME_DIR"
exec > >(tee "$EVIDENCE/session.log") 2>&1
phase=bootstrap
collect() {
  local code=$?
  trap - EXIT
  jq -n --arg phase "$phase" --argjson exitCode "$code" --arg source "$SOURCE_SHA" \
    --arg omarchy "$OMARCHY_SHA" '{source:$source,omarchy:$omarchy,phase:$phase,exitCode:$exitCode}' > "$EVIDENCE/result.json"
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    timeout 5 hyprctl -j clients > "$EVIDENCE/final-clients.json" 2>&1 || true
    timeout 5 hyprctl -j layers > "$EVIDENCE/final-layers.json" 2>&1 || true
    timeout 5 hyprctl configerrors > "$EVIDENCE/config-errors.txt" 2>&1 || true
    timeout 10 grim "$EVIDENCE/final.png" || true
  fi
  jobs -pr | xargs -r kill 2>/dev/null || true
  exit "$code"
}
trap collect EXIT
wait_for() {
  local deadline=$((SECONDS + 60))
  until "$@"; do
    (( SECONDS < deadline )) || { echo "Timed out in $phase: $*"; return 1; }
    sleep 0.3
  done
}
# No host display, devices, session sockets or credentials are mounted.
phase=parent-compositor
weston --backend=headless --renderer=gl --socket=wayland-parent --width=1280 --height=800 \
  --idle-time=0 --no-config > "$EVIDENCE/weston.log" 2>&1 &
wait_for test -S "$XDG_RUNTIME_DIR/wayland-parent"
cat > "$HOME/.config/hypr/looknfeel.lua" <<'LUA'
-- Owned by the disposable test account; Familiar may add its normal hook here.
LUA
cat > "$HOME/.config/hypr/hyprland.lua" <<'LUA'
hl.monitor({ output = "", mode = "1280x800@60", position = "auto", scale = 1 })
hl.config({ general = { layout = "dwindle" }, animations = { enabled = false } })
dofile(os.getenv("HOME") .. "/.config/hypr/looknfeel.lua")
LUA
phase=hyprland
WAYLAND_DISPLAY=wayland-parent AQ_BACKENDS=wayland HYPRLAND_ALLOW_SOFTWARE=1 \
  Hyprland --config "$HOME/.config/hypr/hyprland.lua" > "$EVIDENCE/hyprland.log" 2>&1 &
hypr_pid=$!
discover() {
  kill -0 "$hypr_pid" || return 1
  local socket
  socket=$(find "$XDG_RUNTIME_DIR/hypr" -name .socket.sock -print -quit 2>/dev/null) || return 1
  [[ -n $socket ]] || return 1
  export HYPRLAND_INSTANCE_SIGNATURE=$(basename "$(dirname "$socket")")
  local display
  for display in "$XDG_RUNTIME_DIR"/wayland-*; do
    [[ -S $display && $display != */wayland-parent ]] || continue
    export WAYLAND_DISPLAY=${display##*/}
    timeout 3 hyprctl -j monitors | jq -e 'length > 0' >/dev/null && return 0
  done
  return 1
}
wait_for discover
hyprctl version | tee "$EVIDENCE/hyprland-version.txt"
hyprctl -j monitors > "$EVIDENCE/monitors.json"
# Disable unrelated first-party services; run the real shell and its real bar.
node "$SMOKE_ROOT/tests/desktop/configure.cjs" "$OMARCHY_PATH" "$HOME"
ln -s "$OMARCHY_PATH/themes/tokyo-night" "$HOME/.config/omarchy/current/theme"
phase=omarchy-shell
omarchy-launch-shell > "$EVIDENCE/shell-launcher.log" 2>&1 &
shell_ready() { [[ $(timeout 3 omarchy-shell shell ping 2>/dev/null) == ok ]]; }
wait_for shell_ready
phase=stable-fixture
plugin_id=io.github.tcballard.familiar-desktop
plugin="$HOME/.config/omarchy/plugins/$plugin_id"
baseline=9b948cd4d80e002eff88698d752f08268934b93c
git init "$plugin"
git -C "$plugin" fetch --depth 1 https://github.com/tcballard/omarchy-plugin-familiar-desktop.git "$baseline"
git -C "$plugin" checkout --detach "$baseline"
[[ $(git -C "$plugin" rev-parse HEAD) == "$baseline" ]]
# Bootstrap the signed-off stable fixture with production download/setup helpers.
# This is not a claim to have driven the graphical first-install wizard.
bash "$plugin/install-backend.sh"
library=$(bash "$plugin/install-titlebars.sh")
helper="$plugin/bin/familiar-desktop"
"$helper" titlebars setup --library "$library" --enable --style mac
omarchy-shell shell rescanPlugins
wait_for omarchy plugin enable "$plugin_id"
familiar_ready() { [[ $(timeout 3 omarchy-shell "$plugin_id" ping 2>/dev/null) == ok ]]; }
wait_for familiar_ready
phase=install-candidate
bundle="$SMOKE_ROOT/desktop-bundle"
(cd "$bundle" && sha256sum --check --strict SHA256SUMS)
jq -e --arg sha "$SOURCE_SHA" '.commit == $sha and .channel == "development"' "$bundle/DEV-BUILD.json"
bash "$bundle/install-dev.sh"
[[ $(git -C "$plugin" rev-parse HEAD) == "$SOURCE_SHA" ]]
wait_for familiar_ready
phase=windows
foot --app-id familiar-smoke-a --title 'Familiar fixture A' sleep 600 > "$EVIDENCE/foot-a.log" 2>&1 &
foot --app-id familiar-smoke-b --title 'Familiar fixture B' sleep 600 > "$EVIDENCE/foot-b.log" 2>&1 &
two_windows() { timeout 3 hyprctl -j clients | jq -e '[.[] | select(.class | startswith("familiar-smoke-"))] | length == 2' >/dev/null; }
wait_for two_windows
a=$(hyprctl -j clients | jq -er '.[] | select(.class == "familiar-smoke-a") | .address')
b=$(hyprctl -j clients | jq -er '.[] | select(.class == "familiar-smoke-b") | .address')
"$helper" dock activate-instance "$a"
active_a() { timeout 3 hyprctl -j activewindow | jq -e --arg a "$a" '.address == $a' >/dev/null; }
wait_for active_a
"$helper" dock minimize-instance "$a"
minimized_a() { timeout 3 hyprctl -j clients | jq -e --arg a "$a" 'any(.[]; .address == $a and .workspace.name == "special:minimized")' >/dev/null; }
wait_for minimized_a
hyprctl -j monitors | jq -e 'all(.[]; (.specialWorkspace.name // "") != "special:minimized")'
hyprctl -j clients | jq -e --arg b "$b" 'any(.[]; .address == $b and (.workspace.name | startswith("special:") | not))'
"$helper" dock activate-instance "$a"
wait_for active_a
hyprctl -j clients | jq -e --arg a "$a" 'any(.[]; .address == $a and (.workspace.name | startswith("special:") | not))'
phase=shell-restart
omarchy-shell "$plugin_id" setVisibilityMode always
cp "$HOME/.config/omarchy/familiar-desktop-settings.json" "$EVIDENCE/settings-before.json"
quickshell list -a -j > "$EVIDENCE/shell-before.json"
omarchy restart shell
wait_for familiar_ready
quickshell list -a -j > "$EVIDENCE/shell-after.json"
node "$SMOKE_ROOT/tests/desktop/assert-restart.cjs" "$EVIDENCE" "$OMARCHY_PATH/shell"
jq -e '.visibilityMode == "always"' "$HOME/.config/omarchy/familiar-desktop-settings.json"
wait_for two_windows
"$helper" dock minimize-instance "$a"
wait_for minimized_a
"$helper" dock activate-instance "$a"
wait_for active_a
timeout 10 grim "$EVIDENCE/candidate.png"
hyprctl -j layers > "$EVIDENCE/candidate-layers.json"
jq -e '[.. | objects | select(.namespace? == "familiar-desktop-dock")] | length > 0' "$EVIDENCE/candidate-layers.json"
phase=rollback
bash "$bundle/install-dev.sh" --rollback
[[ $(git -C "$plugin" rev-parse HEAD) == "$baseline" ]]
[[ ! -e "$HOME/.local/state/familiar-desktop/dev-build.json" ]]
wait_for familiar_ready
wait_for two_windows
phase=passed
echo 'PASS: real shell, stable-to-development install, two windows, focus, minimise/restore, shell restart, dock layer and rollback.'
