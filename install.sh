#!/usr/bin/env bash
# Run from a checked-out release of this repository, inside Omarchy.
set -euo pipefail
plugin_id='io.github.tcballard.familiar-desktop'
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"
repository='https://github.com/tcballard/omarchy-plugin-familiar-desktop.git'
style="${1:-mac}"
if [[ "$style" != mac && "$style" != windows ]]; then
  echo 'Usage: ./install.sh [mac|windows]' >&2
  exit 1
fi
for tool in omarchy omarchy-shell cargo hyprctl hyprpm; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Run inside Omarchy Quattro." >&2; exit 1; }
done
if [[ -f "$plugin_dir/manifest.json" ]]; then
  omarchy plugin update "$plugin_id" --yes
  omarchy plugin enable "$plugin_id"
else
  omarchy plugin add "$repository" --enable --yes
fi
if [[ ! -f "$plugin_dir/backend/Cargo.toml" ]]; then
  echo 'The installed plugin does not include window controls yet. Install a release containing this change.' >&2
  exit 1
fi
bash "$plugin_dir/build.sh"
"$plugin_dir/bin/familiar-desktop" titlebars setup --install-dependency --enable --style "$style"
omarchy-shell "$plugin_id" refresh
omarchy-shell "$plugin_id" refreshTitlebars
echo 'Familiar Desktop is ready. Adjust Window controls in its bar settings.'
