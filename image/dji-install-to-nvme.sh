#!/usr/bin/env bash
# First boot: clone the prepared SD system to the sole NVMe and install U-Boot in SPI.
set -Eeuo pipefail

DJI_INSTALL_STATE=/var/lib/dji-nvme-install/state
DJI_MIN_NVME_BYTES=8000000000

dji_board_model() { tr -d '\0' </proc/device-tree/model; }
dji_root_device() { findmnt -n -o SOURCE /; }
dji_nvme_candidates() {
  lsblk -dnpo NAME,TYPE | awk '$2 == "disk" && $1 ~ /^\/dev\/nvme[0-9]+n[0-9]+$/ { print $1 }'
}
dji_is_block_device() { [[ -b "$1" ]]; }
dji_device_size() { blockdev --getsize64 "$1"; }
dji_nvme_is_busy() {
  local disk="$1"
  lsblk -nrpo NAME,MOUNTPOINTS "$disk" | awk 'NF > 1 { busy=1 } END { exit !busy }' && return 0
  swapon --noheadings --output NAME 2>/dev/null | grep -q "^${disk}p[0-9]" && return 0
  return 1
}
dji_spi_available() {
  [[ -r /proc/mtd ]] && compgen -G '/dev/mtdblock[0-9]*' >/dev/null &&
    grep -q 'mtdblock' /proc/partitions
}
dji_installer_available() {
  local help
  command -v armbian-install >/dev/null || return 1
  help="$(armbian-install --help 2>&1)" || return 1
  [[ "$help" == *'--boot'* && "$help" == *'mtd'* ]]
}
dji_boot_config_available() { [[ -f /boot/armbianEnv.txt ]]; }

dji_preflight() {
  local model root disks count disk size
  model="$(dji_board_model)"
  [[ "$model" == *'Orange Pi 5 Plus'* ]] || { echo "Refus: carte inattendue: $model" >&2; return 1; }
  root="$(dji_root_device)"
  [[ "$root" == /dev/mmcblk*p* ]] || { echo "Refus: la racine n'est pas sur SD: $root" >&2; return 1; }
  disks="$(dji_nvme_candidates)"
  count="$(printf '%s\n' "$disks" | awk 'NF { n++ } END { print n+0 }')"
  [[ "$count" == 1 ]] || { echo "Refus: $count NVMe detecte(s), exactement un requis" >&2; return 1; }
  disk="$disks"
  dji_is_block_device "$disk" || { echo "Refus: disque absent: $disk" >&2; return 1; }
  ! dji_nvme_is_busy "$disk" || { echo "Refus: NVMe utilise: $disk" >&2; return 1; }
  size="$(dji_device_size "$disk")"
  [[ "$size" =~ ^[0-9]+$ && "$size" -ge "$DJI_MIN_NVME_BYTES" ]] || {
    echo "Refus: NVMe trop petit: $size octets" >&2; return 1;
  }
  dji_spi_available || { echo 'Refus: memoire SPI non detectee' >&2; return 1; }
  dji_installer_available || { echo 'Refus: installateur Armbian non interactif absent' >&2; return 1; }
  dji_boot_config_available || { echo 'Refus: configuration de demarrage SD absente' >&2; return 1; }
  printf '%s\n' "$disk"
}

dji_verify_target() {
  local disk="$1" partition mountpoint_tmp
  partition="$(lsblk -nrpo NAME,FSTYPE "$disk" | awk '$2 == "ext4" && $1 ~ /p[0-9]+$/ { print $1; exit }')"
  [[ -n "$partition" ]] || { echo 'NVMe: partition ext4 introuvable' >&2; return 1; }
  mountpoint_tmp="$(mktemp -d /tmp/dji-nvme-check.XXXXXX)"
  mount -o ro "$partition" "$mountpoint_tmp"
  local status=0
  [[ -f "$mountpoint_tmp/etc/os-release" &&
     -x "$mountpoint_tmp/usr/local/bin/dji-stream.sh" &&
     -f "$mountpoint_tmp/boot/armbianEnv.txt" ]] || status=1
  umount "$mountpoint_tmp"
  rmdir "$mountpoint_tmp"
  [[ "$status" == 0 ]] || { echo 'NVMe: systeme ou service DJI incomplet' >&2; return 1; }
}

dji_mark_failed() {
  local rc="$1"
  printf 'failed %s exit=%s\n' "$(date -u +%FT%TZ)" "$rc" >"$DJI_INSTALL_STATE"
  trap - ERR
  return "$rc"
}

dji_main() {
  local root target
  root="$(dji_root_device)"
  if [[ "$root" == /dev/nvme* ]]; then
    echo 'Systeme deja demarre sur NVMe; aucune installation.'
    return 0
  fi
  if [[ -e "$DJI_INSTALL_STATE" ]]; then
    echo "Installation deja tentee: $(cat "$DJI_INSTALL_STATE"). Aucun nouvel effacement automatique."
    return 0
  fi
  target="$(dji_preflight)" || return 1
  mkdir -p "$(dirname "$DJI_INSTALL_STATE")"
  printf 'started %s %s\n' "$(date -u +%FT%TZ)" "$target" >"$DJI_INSTALL_STATE"
  trap 'dji_mark_failed "$?"' ERR
  echo "Installation Armbian + DJI vers $target; le NVMe sera efface et le SPI programme."
  armbian-install --target "$target" --boot mtd --fs ext4 --yes || { dji_mark_failed "$?"; return 1; }
  dji_verify_target "$target" || { dji_mark_failed "$?"; return 1; }
  printf 'complete %s %s\n' "$(date -u +%FT%TZ)" "$target" >"$DJI_INSTALL_STATE"
  trap - ERR
  sync
  echo 'Installation terminee. Orange Pi eteint: retirez la SD, puis rallumez pour demarrer sur NVMe.'
  systemctl poweroff --no-block
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  dji_main "$@"
fi
