#!/usr/bin/env bash
# Installed from a CI bundle. No compiler, Cargo, Hyprpm, or source build.
set -Eeuo pipefail
candidate_sha='@SOURCE_SHA@'
candidate_version='@VERSION@'
expected_abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6'
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_id='io.github.tcballard.familiar-desktop'
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"
repository='https://github.com/tcballard/omarchy-plugin-familiar-desktop.git'
style="${1:-windows}"
[[ $# -le 1 && ( "$style" == windows || "$style" == mac ) ]] || { echo 'Usage: bash install-candidate.sh [windows|mac]' >&2; exit 1; }
[[ "$candidate_sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Use the installer inside the built candidate bundle.' >&2; exit 1; }
for tool in omarchy omarchy-shell hyprctl git sha256sum install; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Run this inside Omarchy Quattro." >&2; exit 1; }
done
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Candidate requires Linux x86_64.' >&2; exit 1; }
abi="$(hyprctl version | sed -n 's/^Version ABI string: //p')"
[[ "$abi" == "$expected_abi" ]] || { printf 'Unsupported Hyprland ABI: %s\nExpected: %s\nNothing installed.\n' "$abi" "$expected_abi" >&2; exit 1; }
(cd "$bundle_dir" && sha256sum --check --strict SHA256SUMS)
# The bundle's own SHA256SUMS is transport integrity, not the trust anchor.
# Fetch the reviewed snapshot independently before executing any bundle binary.
verification_stage="$(mktemp -d)"
trap 'rm -rf -- "$verification_stage"' EXIT
git init "$verification_stage"
git -C "$verification_stage" fetch --no-tags "$repository" "$candidate_sha"
[[ "$(git -C "$verification_stage" rev-parse --verify 'FETCH_HEAD^{commit}')" == "$candidate_sha" ]] || exit 1
git -C "$verification_stage" show "$candidate_sha:release-binaries.sha256" > "$verification_stage/pins"
for asset in familiar-desktop-linux-x86_64 "hyprbars-linux-x86_64-$abi.so"; do
  expected="$(awk -v name="$asset" '$2 == name {print $1}' "$verification_stage/pins")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo 'Missing or ambiguous reviewed binary digest.' >&2; exit 1; }
  actual="$(sha256sum "$bundle_dir/$asset" | cut -d " " -f1)"
  [[ "$actual" == "$expected" ]] || { echo "Reviewed digest mismatch: $asset" >&2; exit 1; }
done
chmod u+x "$bundle_dir/familiar-desktop-linux-x86_64"
[[ "$("$bundle_dir/familiar-desktop-linux-x86_64" --version)" == "familiar-desktop $candidate_version" ]] || { echo 'Candidate binary has the wrong version.' >&2; exit 1; }
if [[ -L "$plugin_dir" || ( -e "$plugin_dir" && ! -d "$plugin_dir/.git" ) ]]; then
  echo "Refusing to replace an unmanaged directory: $plugin_dir" >&2; exit 1
fi
if [[ ! -d "$plugin_dir/.git" ]]; then
  # Register only an already verified detached checkout. Adding the remote URL
  # first would expose the moving default branch to the shell's plugin rescan.
  source_stage="$(mktemp -d)"
  trap 'rm -rf -- "$source_stage" "$verification_stage"' EXIT
  git init "$source_stage"
  git -C "$source_stage" fetch --no-tags "$repository" "$candidate_sha"
  [[ "$(git -C "$source_stage" rev-parse --verify 'FETCH_HEAD^{commit}')" == "$candidate_sha" ]] || { echo 'Fetched source does not match the pinned commit.' >&2; exit 1; }
  git -C "$source_stage" checkout --detach "$candidate_sha"
  [[ "$(git -C "$source_stage" rev-parse --verify HEAD)" == "$candidate_sha" ]] || { echo 'Staged source does not match the pinned commit.' >&2; exit 1; }
  omarchy plugin add "$source_stage" --yes
  git -C "$plugin_dir" remote set-url origin "$repository"
  [[ "$(git -C "$plugin_dir" rev-parse --verify HEAD)" == "$candidate_sha" ]] || { echo 'Registered source does not match the pinned commit.' >&2; exit 1; }
fi
[[ -z "$(git -C "$plugin_dir" status --porcelain --untracked-files=all)" ]] || { echo 'Local changes found. Preserve them before testing this candidate.' >&2; exit 1; }
while IFS= read -r ignored; do
  case "$ignored" in bin/familiar-desktop|bin/hyprbars/*|backend/target/*) ;;
    *) echo "Unexpected ignored file: $ignored. Preserve it before testing." >&2; exit 1;;
  esac
done < <(git -C "$plugin_dir" ls-files --others --ignored --exclude-standard)
git -C "$plugin_dir" fetch --no-tags "$repository" "$candidate_sha"
[[ "$(git -C "$plugin_dir" rev-parse --verify 'FETCH_HEAD^{commit}')" == "$candidate_sha" ]] || exit 1
previous_sha="$(git -C "$plugin_dir" rev-parse HEAD)"
printf 'Testing %s (%s). Previous checkout: %s\n' "$candidate_version" "$candidate_sha" "$previous_sha"
# Recover any windows hidden by an earlier candidate before disabling its service.
if [[ -x "$plugin_dir/bin/familiar-desktop" ]] && [[ "$("$plugin_dir/bin/familiar-desktop" --version)" == *0.1.* ]]; then
  "$plugin_dir/bin/familiar-desktop" desktop restore
  "$plugin_dir/bin/familiar-desktop" titlebars disable
fi
omarchy plugin disable "$plugin_id"
git -C "$plugin_dir" checkout --detach "$candidate_sha"
[[ "$(git -C "$plugin_dir" rev-parse --verify HEAD)" == "$candidate_sha" ]] || { echo 'Checked-out source does not match the candidate commit.' >&2; exit 1; }
[[ -z "$(git -C "$plugin_dir" status --porcelain --untracked-files=all)" ]] || { echo 'Checkout is dirty; plugin left disabled.' >&2; exit 1; }
mkdir -p "$plugin_dir/bin/hyprbars/$abi"
install -m 755 "$bundle_dir/familiar-desktop-linux-x86_64" "$plugin_dir/bin/.familiar-desktop.candidate"
mv "$plugin_dir/bin/.familiar-desktop.candidate" "$plugin_dir/bin/familiar-desktop"
install -m 644 "$bundle_dir/hyprbars-linux-x86_64-$abi.so" "$plugin_dir/bin/hyprbars/$abi/.hyprbars.candidate.so"
mv "$plugin_dir/bin/hyprbars/$abi/.hyprbars.candidate.so" "$plugin_dir/bin/hyprbars/$abi/hyprbars.so"
source "$plugin_dir/bar-placement.sh"
familiar_prepare_bar_placement
"$plugin_dir/bin/familiar-desktop" titlebars setup --library "$plugin_dir/bin/hyprbars/$abi/hyprbars.so" --enable --style "$style"
# Enabling rewrites plugin files, so the shell briefly unloads the plugin while it
# reloads. Retry until its IPC target is back; fail if it never returns.
shell_call() {
  local attempt output
  for attempt in {1..25}; do
    if output="$(omarchy-shell "$plugin_id" "$@" 2>&1)"; then [[ -z "$output" ]] || printf '%s\n' "$output"; return 0; fi
    sleep 0.2
  done
  printf '%s\n' "$output" >&2
  echo "Familiar did not respond to '$*' after enabling; the shell may still be reloading." >&2
  return 1
}
omarchy plugin enable "$plugin_id"
familiar_apply_bar_placement
shell_call refresh
shell_call refreshTitlebars
printf '\nFamiliar %s installed for testing. Open the computer icon in the bar.\nRead XPS-TEST.md in this bundle. Previous source: %s\n' "$candidate_version" "$previous_sha"

printf '\nRestart the shell to load updated UI components: omarchy restart shell\n'
