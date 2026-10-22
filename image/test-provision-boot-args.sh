#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/provision-rootfs.sh"
file="$(mktemp)"
trap 'rm -f "$file"' EXIT
printf 'verbosity=1\nextraargs=cma=256M\nrootdev=UUID=abc\n' >"$file"

dji_set_boot_args "$file"
dji_set_boot_args "$file"

grep -q '^rootdev=UUID=abc$' "$file" || exit 1
grep -q '^extraargs=.*cma=256M.*usbcore.quirks=2ca3:0023:i.*video=HDMI-A-1:1920x1080i@50' "$file" || exit 1
[[ "$(grep -o 'usbcore.quirks=2ca3:0023:i' "$file" | wc -l | tr -d ' ')" == 1 ]] || exit 1

echo 'Boot arguments: PASS'
