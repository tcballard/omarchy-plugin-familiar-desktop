#!/usr/bin/env bash
# Download only: never invoke hyprpm or build tools on the user's desktop.
set -Eeuo pipefail
main() {
  local release='v0.1.0'
  local expected_abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6'
  local root_dir abi asset base expected actual destination
  root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Window controls require Linux x86_64.' >&2; return 1; }
  abi="$(hyprctl version | sed -n 's/^Version ABI string: //p')"
  [[ "$abi" == "$expected_abi" ]] || {
    printf 'No prebuilt window controls for Hyprland ABI: %s\nSupported ABI: %s\nNo source build or configuration change was attempted.\n' "$abi" "$expected_abi" >&2
    return 1
  }
  if [[ "${1:-}" == --check ]]; then return 0; fi
  [[ $# == 0 ]] || { echo 'Usage: install-titlebars.sh [--check]' >&2; return 1; }
  asset="hyprbars-linux-x86_64-$abi.so"
  base="https://github.com/tcballard/omarchy-plugin-familiar-desktop/releases/download/$release"
  destination="$root_dir/bin/hyprbars/$abi"
  mkdir -p "$destination"
  titlebars_staging="$(mktemp -d "$destination/.download.XXXXXX")"
  trap 'rm -rf -- "$titlebars_staging"' EXIT
  curl --fail --show-error --silent --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 20 --max-time 180 "$base/SHA256SUMS" -o "$titlebars_staging/SHA256SUMS"
  expected="$(awk -v name="$asset" '$2 == name {print $1}' "$titlebars_staging/SHA256SUMS")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo 'Missing or ambiguous Hyprbars checksum in release.' >&2; return 1; }
  curl --fail --show-error --silent --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 20 --max-time 180 "$base/$asset" -o "$titlebars_staging/hyprbars.so"
  actual="$(sha256sum "$titlebars_staging/hyprbars.so")"
  [[ "${actual%% *}" == "$expected" ]] || { echo 'Hyprbars checksum mismatch; existing library kept.' >&2; return 1; }
  chmod 644 "$titlebars_staging/hyprbars.so"
  mv -f -- "$titlebars_staging/hyprbars.so" "$destination/hyprbars.so"
  printf '%s\n' "$destination/hyprbars.so"
}
main "$@"
