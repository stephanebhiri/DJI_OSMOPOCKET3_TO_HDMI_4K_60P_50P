#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/dji-install-to-nvme.sh"

TEST_BOARD='Orange Pi 5 Plus'
TEST_ROOT='/dev/mmcblk1p1'
TEST_NVMES='/dev/nvme0n1'
TEST_BUSY=0
TEST_SPI=1
TEST_SIZE=64000000000

dji_board_model() { printf '%s\n' "$TEST_BOARD"; }
dji_root_device() { printf '%s\n' "$TEST_ROOT"; }
dji_nvme_candidates() { printf '%s\n' "$TEST_NVMES"; }
dji_nvme_is_busy() { [[ "$TEST_BUSY" == 1 ]]; }
dji_spi_available() { [[ "$TEST_SPI" == 1 ]]; }
dji_device_size() { printf '%s\n' "$TEST_SIZE"; }
dji_is_block_device() { [[ "$1" == /dev/nvme0n1 || "$1" == /dev/nvme1n1 ]]; }
dji_installer_available() { return 0; }
dji_boot_config_available() { return 0; }

assert_ok() {
  local result
  result="$(dji_preflight)" || { echo "FAIL: $1 rejected valid install"; exit 1; }
  [[ "$result" == /dev/nvme0n1 ]] || { echo "FAIL: $1 chose $result"; exit 1; }
}

assert_rejected() {
  if dji_preflight >/dev/null 2>&1; then
    echo "FAIL: $1 was accepted"; exit 1
  fi
}

assert_ok 'single NVMe and SPI'
TEST_BOARD='Orange Pi 5'
assert_rejected 'wrong board'
TEST_BOARD='Orange Pi 5 Plus'
TEST_ROOT='/dev/nvme0n1p1'
assert_rejected 'already booted from NVMe'
TEST_ROOT='/dev/mmcblk1p1'
TEST_NVMES=''
assert_rejected 'missing NVMe'
TEST_NVMES=$'/dev/nvme0n1\n/dev/nvme1n1'
assert_rejected 'multiple NVMe disks'
TEST_NVMES='/dev/nvme0n1'
TEST_BUSY=1
assert_rejected 'mounted NVMe'
TEST_BUSY=0
TEST_SPI=0
assert_rejected 'missing SPI'
TEST_SPI=1
TEST_SIZE=4000000000
assert_rejected 'undersized NVMe'

echo 'Preflight safety checks: PASS'
