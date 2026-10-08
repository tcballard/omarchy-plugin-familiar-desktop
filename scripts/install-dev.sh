#!/usr/bin/env bash
# Explicit opt-in testing of a GitHub Actions artifact, never a release installer.
set -Eeuo pipefail
umask 077
source_sha='@SOURCE_SHA@'
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_id='io.github.tcballard.familiar-desktop'
plugin="$HOME/.config/omarchy/plugins/$plugin_id"
state="${XDG_STATE_HOME:-$HOME/.local/state}/familiar-desktop"
abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6'
asset="hyprbars-linux-x86_64-$abi.so"
library="$plugin/bin/hyprbars/$abi/hyprbars.so"
receipt="$state/dev-build.json"
mode="${1:-install}"
[[ ( "$mode" == install && $# -le 1 ) || ( "$mode" == --rollback && $# -le 2 ) ]] || { echo 'Usage: bash install-dev.sh [--rollback [SNAPSHOT]]'; exit 2; }
for tool in git jq sha256sum flock omarchy hyprctl install; do
  command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }
done
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Requires Linux x86_64.' >&2; exit 1; }
[[ "$(hyprctl version | sed -n 's/^Version ABI string: //p')" == "$abi" ]] || { echo 'Unsupported Hyprland ABI; nothing changed.' >&2; exit 1; }
[[ -d "$plugin/.git" && ! -L "$plugin" ]] || { echo 'Install and finish stable Familiar setup first.' >&2; exit 1; }
[[ -z "$(git -C "$plugin" status --porcelain --untracked-files=all)" ]] || { echo 'Preserve local source changes before testing.' >&2; exit 1; }
while IFS= read -r ignored; do
  case "$ignored" in bin/familiar-desktop|bin/.familiar-desktop.dev|bin/hyprbars/*|backend/target/*) ;;
    *) echo "Unexpected ignored file: $ignored" >&2; exit 1;;
  esac
done < <(git -C "$plugin" ls-files --others --ignored --exclude-standard)
for file in "$plugin/bin/familiar-desktop" "$library"; do
  [[ -f "$file" && ! -L "$file" ]] || { echo "Missing or symlinked installed binary: $file" >&2; exit 1; }
done
mkdir -p "$state/dev-snapshots"
installed_ready() {
  if [[ -f "$plugin/setup-in-app.sh" && ! -L "$plugin/setup-in-app.sh" ]]; then
    bash "$plugin/setup-in-app.sh" status
    return
  fi
  # Older verified installations predate in-app setup. Validate their recorded
  # binaries and ownership directly, including when rolling back to that source.
  [[ ! -e "$receipt" && ! -L "$receipt" && ! -e "$state/setup-pending" ]] || return 1
  local pins name file expected actual
  pins="$(git -C "$plugin" show HEAD:release-binaries.sha256)" || { echo 'Existing source has no reviewed binary pins; stop for repair.' >&2; return 1; }
  for name in familiar-desktop-linux-x86_64 "$asset"; do
    file="$plugin/bin/familiar-desktop"
    [[ "$name" != "$asset" ]] || file="$library"
    expected="$(awk -v name="$name" '$2 == name {print $1}' <<< "$pins")"
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || return 1
    actual="$(sha256sum "$file")"
    [[ "${actual%% *}" == "$expected" ]] || { echo "Existing binary differs from its source pin: $name" >&2; return 1; }
  done
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  jq -e --arg source "$plugin" --arg library "$library" \
    '.source == $source and .library == $library' "$config/omarchy/familiar-titlebars/owner.json" >/dev/null || return 1
  grep -qF -- '-- BEGIN Familiar Desktop title bars' "$config/hypr/looknfeel.lua" || return 1
  echo 'Verified existing installation without in-app setup.'
}
if [[ "$mode" == install ]]; then
  # Existing install must be ready; this checks its stable pins or previous dev receipt.
  installed_ready
fi
exec 9>"$state/setup.lock"
flock -n 9 || { echo 'Another setup operation is running.' >&2; exit 1; }
current="$(git -C "$plugin" rev-parse HEAD)"
verify_assets() {
  local dir="$1" metadata="$2" name actual expected
  for name in familiar-desktop-linux-x86_64 "$asset"; do
    [[ -f "$dir/$name" && ! -L "$dir/$name" ]] || return 1
    expected="$(jq -er --arg name "$name" '.assets[$name]' "$metadata")"
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || return 1
    actual="$(sha256sum "$dir/$name")"
    [[ "${actual%% *}" == "$expected" ]] || return 1
  done
}
if [[ "$mode" == install ]]; then
  [[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Use the installer from a CI development artifact.' >&2; exit 1; }
  (cd "$bundle" && sha256sum --check --strict SHA256SUMS)
  jq -e --arg sha "$source_sha" 'select(.schemaVersion == 1 and .channel == "development" and .commit == $sha and .repository == "tcballard/omarchy-plugin-familiar-desktop")' "$bundle/DEV-BUILD.json" >/dev/null
  verify_assets "$bundle" "$bundle/DEV-BUILD.json"
  git -C "$plugin" fetch --no-tags https://github.com/tcballard/omarchy-plugin-familiar-desktop.git "$source_sha"
  [[ "$(git -C "$plugin" rev-parse 'FETCH_HEAD^{commit}')" == "$source_sha" ]] || exit 1
  snapshot="$(mktemp -d "$state/dev-snapshots/build-XXXXXXXX")"
  cp "$plugin/bin/familiar-desktop" "$snapshot/familiar-desktop-linux-x86_64"
  cp "$library" "$snapshot/$asset"
  [[ ! -e "$receipt" ]] || cp "$receipt" "$snapshot/dev-build.json"
  jq -n --arg previous "$current" --arg target "$source_sha" --arg source "$plugin" \
    '{previous:$previous,target:$target,source:$source}' > "$snapshot/snapshot.json"
  (cd "$snapshot" && sha256sum ./* > SHA256SUMS)
  printf '%s\n' "$snapshot" > "$state/dev-rollback.new"
  mv "$state/dev-rollback.new" "$state/dev-rollback"
  target="$source_sha"
  bytes="$bundle"
else
  snapshot="${2:-$(cat "$state/dev-rollback")}"
  snapshot="$(realpath -e -- "$snapshot")"
  [[ "$snapshot" == "$state/dev-snapshots/"* && -d "$snapshot" && ! -L "$snapshot" ]] || { echo 'Unknown rollback snapshot.' >&2; exit 1; }
  (cd "$snapshot" && sha256sum --check --strict SHA256SUMS)
  [[ -f "$snapshot/familiar-desktop-linux-x86_64" && ! -L "$snapshot/familiar-desktop-linux-x86_64" && -f "$snapshot/$asset" && ! -L "$snapshot/$asset" ]] || exit 1
  jq -e --arg source "$plugin" --arg current "$current" 'select(.source == $source and (.target == $current or .previous == $current))' "$snapshot/snapshot.json" >/dev/null
  target="$(jq -er '.previous' "$snapshot/snapshot.json")"
  [[ "$target" =~ ^[0-9a-f]{40}$ ]] || exit 1
  git -C "$plugin" cat-file -e "$target^{commit}"
  bytes="$snapshot"
fi
printf 'Installing source %s\nRollback snapshot: %s\n' "$target" "$snapshot"
trap 'echo "Installation did not complete. Recover with: bash $bundle/install-dev.sh --rollback $snapshot" >&2' ERR
# Reset taskbar placement with this bundle's verified helper, before replacing
# the installed backend (the previous stable version may not know taskbar).
# This helper operates only on the user's placement journal, not titlebar ownership.
if [[ -e "$HOME/.local/state/familiar-desktop/taskbar/placement.json" || -L "$HOME/.local/state/familiar-desktop/taskbar/placement.json" ]]; then
  (cd "$bundle" && sha256sum --check --strict SHA256SUMS)
  verify_assets "$bundle" "$bundle/DEV-BUILD.json"
  taskbar_helper="$(mktemp "$state/taskbar-helper.XXXXXXXX")"
  install -m 755 "$bundle/familiar-desktop-linux-x86_64" "$taskbar_helper"
  taskbar_status=0
  "$taskbar_helper" taskbar reset || taskbar_status=$?
  rm -f "$taskbar_helper"
  [[ "$taskbar_status" == 0 ]] || exit "$taskbar_status"
fi
# Do not run unverified partial binaries when recovering a failed install.
if [[ "$mode" == install ]]; then
  "$plugin/bin/familiar-desktop" desktop restore
  "$plugin/bin/familiar-desktop" titlebars disable
else
  omarchy plugin disable "$plugin_id"
  # The helper derives ownership from its executable path. Restore the verified
  # previous helper at that path before using it to recover a partial install.
  install -m 755 "$snapshot/familiar-desktop-linux-x86_64" "$plugin/bin/.familiar-desktop.dev"
  mv "$plugin/bin/.familiar-desktop.dev" "$plugin/bin/familiar-desktop"
  "$plugin/bin/familiar-desktop" desktop restore
  "$plugin/bin/familiar-desktop" titlebars disable
fi
omarchy plugin disable "$plugin_id"
git -C "$plugin" checkout --detach "$target"
[[ "$(git -C "$plugin" rev-parse HEAD)" == "$target" ]]
install -m 755 "$bytes/familiar-desktop-linux-x86_64" "$plugin/bin/.familiar-desktop.dev"
mv "$plugin/bin/.familiar-desktop.dev" "$plugin/bin/familiar-desktop"
install -m 644 "$bytes/$asset" "$library.dev"
mv "$library.dev" "$library"
if [[ "$mode" == install ]]; then
  jq --arg source "$plugin" '. + {sourceDirectory:$source}' "$bundle/DEV-BUILD.json" > "$receipt.new"
  mv "$receipt.new" "$receipt"
elif [[ -f "$snapshot/dev-build.json" ]]; then
  cp "$snapshot/dev-build.json" "$receipt.new"
  mv "$receipt.new" "$receipt"
else
  rm -f "$receipt"
fi
# --enable is deliberately omitted: it overwrites dockEnabled, titlebarsEnabled
# and titlebarMode. The restarted controller reapplies the user's saved choices.
"$plugin/bin/familiar-desktop" titlebars setup --library "$library"
flock -u 9
installed_ready
omarchy plugin enable "$plugin_id"
omarchy restart shell
trap - ERR
printf '\nSource installed: %s\nRollback: bash %q --rollback %q\n' "$target" "$bundle/install-dev.sh" "$snapshot"
