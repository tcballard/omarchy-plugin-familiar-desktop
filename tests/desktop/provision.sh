#!/usr/bin/env bash
set -Eeuo pipefail
[[ $(id -u) == 0 && $(uname -n) == familiar-smoke ]] || exit 2
: "${SOURCE_SHA:?}" "${OMARCHY_SHA:?}"
root=/opt/familiar-smoke
mkdir -p "$root/smoke-evidence"
echo 'Server = https://archive.archlinux.org/repos/2026/09/30/$repo/os/$arch' > /etc/pacman.d/mirrorlist
retry() { local n; for n in 1 2 3; do "$@" && return; sleep 5; done; return 1; }
retry pacman -Syyuu --noconfirm
retry pacman -S --needed --noconfirm git jq nodejs dbus sudo socat curl inotify-tools hyprland quickshell \
  mesa foot grim gcc wayland qt6-declarative qt6-wayland qt6-multimedia qt6-svg qt6-imageformats ttf-dejavu
pacman -Q > "$root/smoke-evidence/packages.txt"
uname -a > "$root/smoke-evidence/kernel.txt"
ls -l /dev/dri > "$root/smoke-evidence/virtual-gpu.txt"
# Match Omarchy’s installed path, including absolute QML imports in stable Familiar.
ln -s "$root/upstream-omarchy" /usr/share/omarchy
loginctl enable-linger familiar-smoke
chown familiar-smoke:familiar-smoke "$root/smoke-evidence"
systemctl stop getty@tty1.service
cat > /etc/systemd/system/familiar-desktop-smoke.service <<UNIT
[Unit]
After=systemd-user-sessions.service
[Service]
Type=oneshot
User=familiar-smoke
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty-force
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
Environment=FAMILIAR_DISPOSABLE_SMOKE=1
Environment=SOURCE_SHA=$SOURCE_SHA
Environment=OMARCHY_SHA=$OMARCHY_SHA
Environment=SMOKE_ROOT=$root
ExecStart=/usr/bin/dbus-run-session -- /bin/bash $root/tests/desktop/session.sh
TimeoutStartSec=600
KillMode=control-group
UNIT
systemctl daemon-reload
