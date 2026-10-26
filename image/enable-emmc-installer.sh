#!/usr/bin/env bash
# Turn a personal 6 GiB runtime image into the one-shot eMMC installer variant.
set -Eeuo pipefail

image=${1:?raw image path required}
[[ $EUID == 0 ]] || { echo 'Run as root' >&2; exit 1; }
[[ -f $image && $(stat -c %s "$image") == 6442450944 ]] || {
    echo 'Expected a 6 GiB raw image' >&2
    exit 1
}

loop=''
mountpoint=''
cleanup() {
    if [[ -n $mountpoint ]]; then
        mountpoint -q "$mountpoint" && umount "$mountpoint"
        rmdir "$mountpoint"
    fi
    [[ -z $loop ]] || losetup -d "$loop"
}
trap cleanup EXIT

loop=$(losetup --find --show --partscan "$image")
mountpoint=$(mktemp -d /tmp/osmo-emmc-image.XXXXXX)
mount "${loop}p1" "$mountpoint"
[[ -x $mountpoint/usr/local/sbin/osmo-install-emmc.sh &&
   -f $mountpoint/usr/share/doc/dji-osmo2hdmi/device-build.txt ]] || {
    echo 'This is not the prepared OSMO2HDMI image' >&2
    exit 1
}
units="$mountpoint/etc/systemd/system/multi-user.target.wants"
for name in osmo-hdmi50 dji-h264-stream dji-hdmi-audio dji-install-to-nvme; do
    rm -f "$units/$name.service"
done
ln -s ../osmo-install-emmc.service "$units/osmo-install-emmc.service"
grep -q 'VERSION_CODENAME=noble' "$mountpoint/etc/os-release"
[[ -L $units/osmo-install-emmc.service && ! -e $units/dji-h264-stream.service ]]
sync
echo 'One-shot eMMC installer enabled; runtime services disabled on the SD image.'
