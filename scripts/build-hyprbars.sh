#!/usr/bin/env bash
# CI only. Run inside the pinned Arch repository snapshot from release.yml.
set -Eeuo pipefail
expected_abi='efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6'
plugin_commit='7644cecdb947060682891a0db2a0cdc5c0b9e704'
root_dir="$(pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
# This is the installed package, including generated headers, rather than a
# locally fabricated version.h or an override of Hyprland's compatibility check.
test "$(pkg-config --modversion hyprland)" = 0.56.2
# Preprocess the real plugin header, then compile only its ABI function. Including
# the whole header in an executable also instantiates compositor-only globals.
printf '#include <hyprland/src/plugins/PluginAPI.hpp>\n' > "$work_dir/header.cpp"
# shellcheck disable=SC2046
c++ -std=c++23 $(pkg-config --cflags hyprland) -dM -E "$work_dir/header.cpp" > "$work_dir/macros"
{
  echo '#include <format>'
  echo '#include <string>'
  echo '#include <string_view>'
  echo '#include <iostream>'
  grep -E '^#define (GIT_COMMIT_HASH|AQUAMARINE_VERSION|HYPRUTILS_VERSION|HYPRGRAPHICS_VERSION|HYPRCURSOR_VERSION|HYPRLANG_VERSION) ' "$work_dir/macros"
  sed -n '/^APICALL inline EXPORT const char\* __hyprland_api_get_client_hash()/,/^}/p' /usr/include/hyprland/src/plugins/PluginAPI.hpp | sed 's/APICALL inline EXPORT //'
  echo 'int main() { std::cout << __hyprland_api_get_client_hash(); }'
} > "$work_dir/abi.cpp"
c++ -std=c++23 "$work_dir/abi.cpp" -o "$work_dir/abi"
test "$("$work_dir/abi")" = "$expected_abi"
git init "$work_dir/plugins"
git -C "$work_dir/plugins" remote add origin https://github.com/hyprwm/hyprland-plugins.git
git -C "$work_dir/plugins" fetch --depth 1 origin "$plugin_commit"
git -C "$work_dir/plugins" checkout --detach FETCH_HEAD
test "$(git -C "$work_dir/plugins" rev-parse HEAD)" = "$plugin_commit"
# GCC's spelling is -fno-gnu-unique (the upstream makefile uses a linker spelling).
make -C "$work_dir/plugins/hyprbars" EXTRA_FLAGS=-fno-gnu-unique
mkdir -p "$root_dir/hyprbars-assets"
asset="hyprbars-linux-x86_64-$expected_abi.so"
install -m644 "$work_dir/plugins/hyprbars/hyprbars.so" "$root_dir/hyprbars-assets/$asset"
readelf -h "$root_dir/hyprbars-assets/$asset" | tee "$root_dir/hyprbars-assets/HYPRBARS-ELF.txt"
grep -q 'Advanced Micro Devices X86-64' "$root_dir/hyprbars-assets/HYPRBARS-ELF.txt"
cp "$work_dir/plugins/LICENSE" "$root_dir/hyprbars-assets/HYPRBARS-LICENSE.txt"
{
  printf 'Hyprbars upstream: https://github.com/hyprwm/hyprland-plugins/tree/%s\nABI: %s\nArch snapshot: 2026/09/30\n' "$plugin_commit" "$expected_abi"
  c++ --version
  pacman -Q
} > "$root_dir/hyprbars-assets/HYPRBARS-BUILD.txt"
