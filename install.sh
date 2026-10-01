#!/usr/bin/env bash
# Interactive terminal entry point, including when downloaded from a release.
set -euo pipefail
trap 'printf "\nFamiliar setup stopped at line %s. Fix the error above and rerun this command.\n" "$LINENO" >&2' ERR
main() {
export PATH="$HOME/.cargo/bin:$PATH"
plugin_id='io.github.tcballard.familiar-desktop'
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"
repository='https://github.com/tcballard/omarchy-plugin-familiar-desktop.git'
release='v0.0.2'
style="${1:-mac}"
if [[ $# -gt 1 || ( "$style" != mac && "$style" != windows ) ]]; then
  echo 'Usage: bash install.sh [mac|windows]' >&2
  exit 1
fi
step() { printf '\n[%s/5] %s\n' "$1" "$2"; }
step 1 'Checking Omarchy and build tools'
for tool in omarchy omarchy-shell hyprctl hyprpm; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Run inside Omarchy Quattro." >&2; exit 1; }
done
hyprctl -j version >/dev/null
packages=()
for pair in 'git:git' 'make:base-devel' 'cc:base-devel'; do
  command -v "${pair%%:*}" >/dev/null || packages+=("${pair#*:}")
done
if ! command -v cargo >/dev/null && ! command -v rustup >/dev/null; then packages+=(rust); fi
if (( ${#packages[@]} )); then
  echo 'Installing missing build tools; pacman may ask for your password.'
  sudo pacman -S --needed "${packages[@]}"
fi
if command -v rustup >/dev/null; then
  rustup toolchain install stable --profile minimal
  export RUSTUP_TOOLCHAIN=stable
fi
cargo --version
step 2 "Installing Familiar Desktop $release"
if [[ ! -f "$plugin_dir/manifest.json" ]]; then
  omarchy plugin add "$repository" --yes
fi
[[ -d "$plugin_dir/.git" ]] || { echo "Expected a Git installation at $plugin_dir" >&2; exit 1; }
if [[ -n "$(git -C "$plugin_dir" status --porcelain --untracked-files=no)" ]]; then
  echo 'Familiar has local source changes. Commit or stash them before updating.' >&2
  exit 1
fi
git -C "$plugin_dir" fetch "$repository" "refs/tags/$release:refs/tags/$release"
git -C "$plugin_dir" checkout --detach "$release"
step 3 'Building the Rust backend'
bash "$plugin_dir/build.sh"
step 4 'Preparing window controls'
helper="$plugin_dir/bin/familiar-desktop"
echo 'Checking for a reusable, compatible Hyprbars installation.'
if ! "$helper" titlebars setup --enable --style "$style"; then
  echo 'Preparing or updating Hyprbars through hyprpm.'
  echo 'This may download Hyprland source for matching build headers and take several minutes.'
  echo 'It does not replace your installed Hyprland. Follow any dependency prompts below.'
  "$helper" titlebars setup --install-dependency --enable --style "$style"
fi
step 5 'Enabling the dock and window controls'
omarchy plugin enable "$plugin_id"
omarchy-shell "$plugin_id" refresh
omarchy-shell "$plugin_id" refreshTitlebars
"$helper" --version
printf '\nFamiliar Desktop %s is installed. Open Familiar Desktop in the bar to adjust Window controls.\n' "$release"
}
main "$@"
