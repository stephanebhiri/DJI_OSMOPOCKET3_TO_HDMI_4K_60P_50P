#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
STATE_FILE="$tmp/state"
source "$(dirname "$0")/osmo-install-emmc.sh"

TEST_BOARD='Orange Pi 5 Plus'
TEST_ROOT='/dev/mmcblk1p1'
TEST_TARGETS='/dev/mmcblk0'
TEST_BUSY=0
TEST_HDMI=1
TEST_SOURCE_OK=1
TEST_TARGET_BYTES=61865984000

dji_board_model() { printf '%s\n' "$TEST_BOARD"; }
dji_root_device() { printf '%s\n' "$TEST_ROOT"; }
dji_storage_type() { [[ $1 == /dev/mmcblk1 ]] && printf SD || printf MMC; }
dji_device_size() {
    [[ $1 == /dev/mmcblk1 ]] && printf 31927042048 || printf '%s' "$TEST_TARGET_BYTES"
}
dji_partition_end() { printf 6441410560; }
dji_target_candidates() { printf '%s\n' "$TEST_TARGETS"; }
dji_is_target_busy() { [[ $TEST_BUSY == 1 ]]; }
dji_hdmi_supported() { [[ $TEST_HDMI == 1 ]]; }
dji_source_files_valid() { [[ $TEST_SOURCE_OK == 1 ]]; }

assert_rejected() {
    if (preflight) >/dev/null 2>&1; then
        echo "Accepted unsafe case: $1" >&2
        exit 1
    fi
}

[[ $(preflight) == *'TARGET=/dev/mmcblk0'* ]]
TEST_BOARD='Orange Pi 5'
assert_rejected 'wrong board'
TEST_BOARD='Orange Pi 5 Plus'
TEST_ROOT='/dev/mmcblk0p1'
assert_rejected 'booted from eMMC'
TEST_ROOT='/dev/mmcblk1p1'
TEST_TARGETS=''
assert_rejected 'missing eMMC'
TEST_TARGETS=$'/dev/mmcblk0\n/dev/mmcblk2'
assert_rejected 'multiple eMMCs'
TEST_TARGETS='/dev/mmcblk0'
TEST_BUSY=1
assert_rejected 'mounted eMMC'
TEST_BUSY=0
TEST_TARGET_BYTES=7000000000
assert_rejected 'small eMMC'
TEST_TARGET_BYTES=61865984000
TEST_HDMI=0
assert_rejected 'no HDMI-A-2 1080i50'
TEST_HDMI=1
TEST_SOURCE_OK=0
assert_rejected 'source files mismatch'
TEST_SOURCE_OK=1
touch "$STATE_FILE"
assert_rejected 'previous install attempt'

SOURCE_BYTES=4194304
dd if=/dev/urandom of="$tmp/source" bs=1m count=4 status=none
dji_clone_and_verify "$tmp/source" "$tmp/target" "$SOURCE_BYTES" >/dev/null
cmp "$tmp/source" "$tmp/target" >/dev/null
dji_copy_source() { printf 'corrupted target\n' >"$2"; }
if (dji_clone_and_verify "$tmp/source" "$tmp/target" "$SOURCE_BYTES") >/dev/null 2>&1; then
    echo 'Accepted a corrupted eMMC readback' >&2
    exit 1
fi
echo 'eMMC installer preflight refusal cases: PASS'
