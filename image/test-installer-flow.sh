#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/dji-install-to-nvme.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
DJI_INSTALL_STATE="$tmp_dir/state"

dji_root_device() { echo /dev/mmcblk1p1; }
dji_preflight() { echo /dev/nvme0n1; }
dji_verify_target() { [[ "$1" == /dev/nvme0n1 ]]; }
armbian-install() { printf '%s\n' "$*" >"$tmp_dir/installer-args"; }
systemctl() { printf '%s\n' "$*" >"$tmp_dir/power-action"; }
sync() { :; }

dji_main
[[ "$(cat "$tmp_dir/installer-args")" == '--target /dev/nvme0n1 --boot mtd --fs ext4 --yes' ]] || exit 1
[[ "$(cat "$tmp_dir/power-action")" == 'poweroff --no-block' ]] || exit 1
grep -q '^complete ' "$DJI_INSTALL_STATE" || exit 1

echo 'NVMe/SPI install flow: PASS'

rm -f "$DJI_INSTALL_STATE" "$tmp_dir/power-action"
armbian-install() { return 23; }
if dji_main; then
  echo 'FAIL: installer error reported success' >&2; exit 1
fi
[[ ! -e "$tmp_dir/power-action" ]] || { echo 'FAIL: powered off after installer failure' >&2; exit 1; }
grep -q '^failed ' "$DJI_INSTALL_STATE" || { echo 'FAIL: failure state missing' >&2; exit 1; }
echo 'Installer failure stops poweroff: PASS'
