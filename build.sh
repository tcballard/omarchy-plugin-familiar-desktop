#!/usr/bin/env bash
# Explicit terminal build. Never invoked by the hosted shell.
set -euo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
command -v cargo >/dev/null || { echo 'Install Rust (cargo) before building Familiar Desktop.' >&2; exit 1; }
build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/familiar-desktop-build"
cargo build --manifest-path "$root_dir/backend/Cargo.toml" --target-dir "$build_dir" --release --locked
mkdir -p "$root_dir/bin"
new_binary="$(mktemp "$root_dir/bin/.familiar-desktop.XXXXXX")"
trap 'rm -f -- "$new_binary"' EXIT
cp -- "$build_dir/release/familiar-desktop" "$new_binary"
chmod 755 "$new_binary"
mv -f -- "$new_binary" "$root_dir/bin/familiar-desktop"
"$root_dir/bin/familiar-desktop" --version
