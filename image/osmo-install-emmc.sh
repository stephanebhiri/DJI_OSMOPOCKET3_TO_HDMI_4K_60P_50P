#!/usr/bin/env bash
# Clone the prepared, read-only SD image to the Orange Pi 5 Plus eMMC once.
set -Eeuo pipefail

SOURCE_BYTES=6442450944
STATE_FILE=/var/lib/osmo-emmc-install/state

die() { echo "Installation eMMC refusee: $*" >&2; exit 1; }

preflight() {
    local root source_disk source_name source_end target_name target_size
    local -a candidates=()

    grep -aq 'Orange Pi 5 Plus' /proc/device-tree/model || die 'carte non reconnue'
    root=$(findmnt -n -o SOURCE /)
    [[ $root =~ ^/dev/mmcblk[0-9]+p[0-9]+$ ]] || die "racine non MMC: $root"
    source_disk=${root%p[0-9]*}
    source_name=${source_disk##*/}
    [[ $(cat "/sys/block/$source_name/device/type") == SD ]] || die 'le systeme ne demarre pas sur microSD'
    [[ $(cat "/sys/block/$source_name/queue/logical_block_size") == 512 ]] || die 'secteurs SD inattendus'
    source_end=$(( ($(cat "/sys/class/block/${root##*/}/start") + $(cat "/sys/class/block/${root##*/}/size")) * 512 ))
    (( source_end <= SOURCE_BYTES )) || die 'la partition SD a deja ete agrandie'
    (( $(blockdev --getsize64 "$source_disk") >= SOURCE_BYTES )) || die 'carte SD trop petite'

    for path in /sys/block/mmcblk[0-9]*; do
        target_name=${path##*/}
        [[ $target_name =~ ^mmcblk[0-9]+$ ]] || continue
        [[ $path != "/sys/block/$source_name" ]] || continue
        [[ $(cat "$path/device/type") == MMC ]] && candidates+=("/dev/$target_name")
    done
    (( ${#candidates[@]} == 1 )) || die "${#candidates[@]} eMMC detectee(s), exactement une requise"
    target=${candidates[0]}
    target_size=$(blockdev --getsize64 "$target")
    (( target_size >= SOURCE_BYTES + 1073741824 )) || die 'eMMC trop petite'
    if lsblk -nrpo MOUNTPOINTS "$target" | grep -q '[^[:space:]]'; then
        die 'eMMC deja montee'
    fi
    if swapon --show=NAME --noheadings | grep -Fq "$target"; then
        die 'eMMC utilisee comme swap'
    fi
    [[ ! -e $STATE_FILE ]] || die 'une installation a deja ete tentee; reflasher la SD pour recommencer'
    printf 'SOURCE=%s\nTARGET=%s\nBYTES=%s\n' "$source_disk" "$target" "$SOURCE_BYTES"
}

install_emmc() {
    local source_disk target target_partition mountpoint path fsck_status
    preflight
    source_disk=$(findmnt -n -o SOURCE /)
    source_disk=${source_disk%p[0-9]*}
    target=''
    for path in /sys/block/mmcblk[0-9]*; do
        [[ ${path##*/} =~ ^mmcblk[0-9]+$ ]] || continue
        [[ $path != "/sys/block/${source_disk##*/}" ]] || continue
        if [[ $(cat "$path/device/type") == MMC ]]; then
            target="/dev/${path##*/}"
        fi
    done
    [[ -n $target ]] || die 'eMMC introuvable apres verification'

    mkdir -p "${STATE_FILE%/*}"
    printf 'started %s %s\n' "$(date -u +%FT%TZ)" "$target" > "$STATE_FILE"
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
