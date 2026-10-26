#!/usr/bin/env bash
# Clone the prepared, read-only SD image to the Orange Pi 5 Plus eMMC once.
set -Eeuo pipefail

SOURCE_BYTES=6442450944
STATE_FILE=${STATE_FILE:-/var/lib/osmo-emmc-install/state}

die() { echo "Installation eMMC refusee: $*" >&2; exit 1; }

dji_board_model() { tr -d '\000' </proc/device-tree/model; }
dji_root_device() { findmnt -n -o SOURCE /; }
dji_storage_type() { cat "/sys/block/${1##*/}/device/type"; }
dji_device_size() { blockdev --getsize64 "$1"; }
dji_partition_end() {
    local name=${1##*/}
    echo $(( ($(cat "/sys/class/block/$name/start") + $(cat "/sys/class/block/$name/size")) * 512 ))
}
dji_target_candidates() {
    local path name
    for path in /sys/block/mmcblk[0-9]*; do
        name=${path##*/}
        [[ $name =~ ^mmcblk[0-9]+$ ]] || continue
        [[ $(dji_storage_type "/dev/$name") == MMC ]] && printf '/dev/%s\n' "$name"
    done
}
dji_is_target_busy() {
    lsblk -nrpo MOUNTPOINTS "$1" | grep -q '[^[:space:]]' ||
        swapon --show=NAME --noheadings | grep -Fq "$1"
}
dji_hdmi_supported() {
    modetest -M rockchip -c | /usr/local/bin/parse-hdmi-mode.sh >/dev/null
}
dji_source_files_valid() {
    local manifest=/usr/share/doc/dji-osmo2hdmi/installer-critical.sha256
    [[ -s $manifest ]] && (cd / && sha256sum -c "$manifest" --quiet)
}

preflight() {
    local root source_disk source_name source_end target target_size candidate
    local -a candidates=()

    [[ $(dji_board_model) == *'Orange Pi 5 Plus'* ]] || die 'carte non reconnue'
    root=$(dji_root_device)
    [[ $root =~ ^/dev/mmcblk[0-9]+p[0-9]+$ ]] || die "racine non MMC: $root"
    source_disk=${root%p[0-9]*}
    source_name=${source_disk##*/}
    [[ $(dji_storage_type "$source_disk") == SD ]] || die 'le systeme ne demarre pas sur microSD'
    source_end=$(dji_partition_end "$root")
    (( source_end <= SOURCE_BYTES )) || die 'la partition SD a deja ete agrandie'
    (( $(dji_device_size "$source_disk") >= SOURCE_BYTES )) || die 'carte SD trop petite'

    while IFS= read -r candidate; do
        [[ -n $candidate && $candidate != "$source_disk" ]] && candidates+=("$candidate")
    done < <(dji_target_candidates)
    (( ${#candidates[@]} == 1 )) || die "${#candidates[@]} eMMC detectee(s), exactement une requise"
    target=${candidates[0]}
    target_size=$(dji_device_size "$target")
    (( target_size >= SOURCE_BYTES + 1073741824 )) || die 'eMMC trop petite'
    dji_is_target_busy "$target" && die 'eMMC utilisee ou deja montee'
    [[ ! -e $STATE_FILE ]] || die 'une installation a deja ete tentee; reflasher la SD pour recommencer'
    dji_hdmi_supported || die 'HDMI-A-2 1080i50 absent'
    dji_source_files_valid || die 'fichiers source invalides'
    printf 'SOURCE=%s\nTARGET=%s\nBYTES=%s\n' "$source_disk" "$target" "$SOURCE_BYTES"
}

install_emmc() {
    local source_disk target target_partition mountpoint fsck_status details
    details=$(preflight)
    source_disk=$(awk -F= '$1=="SOURCE" {print $2}' <<< "$details")
    target=$(awk -F= '$1=="TARGET" {print $2}' <<< "$details")
    [[ -b $source_disk && -b $target ]] || die 'source ou cible absente apres verification'

    mkdir -p "${STATE_FILE%/*}"
    printf 'started %s source=%s target=%s bytes=%s\n' "$(date -u +%FT%TZ)" "$source_disk" "$target" "$SOURCE_BYTES" > "$STATE_FILE"
    trap 'status=$?; if (( status != 0 )); then mount -o remount,rw / 2>/dev/null || true; printf "failed %s status=%s\n" "$(date -u +%FT%TZ)" "$status" >> "$STATE_FILE" 2>/dev/null || true; sync; echo "Installation eMMC interrompue; consulter $STATE_FILE et le journal systeme." >&2; fi' EXIT
    sync
    mount -o remount,ro / || die 'impossible de figer la carte SD en lecture seule'
    echo "Copie de $source_disk vers $target; ne pas couper l'alimentation."
    dd if="$source_disk" of="$target" bs=4M count=1536 conv=fsync status=progress
    echo 'Verification bit a bit de la copie...'
    cmp -n "$SOURCE_BYTES" "$source_disk" "$target" || die 'verification eMMC echouee'

    parted -s -f "$target" print >/dev/null
    parted -s "$target" resizepart 1 100%
    partprobe "$target"
    udevadm settle
    target_partition=${target}p1
    [[ -b $target_partition ]] || die 'partition eMMC absente'
    fsck_status=0
    e2fsck -f -y "$target_partition" || fsck_status=$?
    (( fsck_status <= 1 )) || die "controle ext4 echoue (code $fsck_status)"
    resize2fs "$target_partition"

    mountpoint=$(mktemp -d /run/osmo-emmc.XXXXXX)
    mount "$target_partition" "$mountpoint"
    [[ -x $mountpoint/usr/local/bin/dji-stream.sh && -f $mountpoint/etc/os-release ]] || die 'systeme copie incomplet'
    unlink "$mountpoint/etc/systemd/system/multi-user.target.wants/osmo-install-emmc.service"
    ln -s ../dji-h264-stream.service "$mountpoint/etc/systemd/system/multi-user.target.wants/dji-h264-stream.service"
    ln -s ../osmo-hdmi50.service "$mountpoint/etc/systemd/system/multi-user.target.wants/osmo-hdmi50.service"
    if [[ -f $mountpoint/etc/systemd/system/dji-hdmi-audio.service ]]; then
        ln -s ../dji-hdmi-audio.service "$mountpoint/etc/systemd/system/multi-user.target.wants/dji-hdmi-audio.service"
    fi
    printf 'complete %s\n' "$(date -u +%FT%TZ)" > "$mountpoint/var/lib/osmo-emmc-install/state"
    sync
    umount "$mountpoint"
    rmdir "$mountpoint"
    trap - EXIT
    echo 'Installation terminee. Retirer la SD apres extinction, puis rallumer.'
    systemctl poweroff --no-block
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    case ${1:-} in
        --preflight) preflight ;;
        '') install_emmc ;;
        *) die "option inconnue: $1" ;;
    esac
fi
