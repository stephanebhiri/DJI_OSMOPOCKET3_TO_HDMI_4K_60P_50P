#!/usr/bin/env bash
# Build the 6 GiB public Orange Pi 5 Plus SD installer on ARM64 Linux.
set -Eeuo pipefail

base=${1:?verified Armbian .img.xz required}
output=${2:?output .img required}
project=$(cd "$(dirname "$0")/.." && pwd)
lock=$project/image/source-lock.txt
[[ $(uname -s) == Linux && $(uname -m) == aarch64 && $EUID == 0 ]] || {
    echo 'Run as root on an ARM64 Linux build host' >&2; exit 1;
}
[[ -f $base && ! -e $output ]] || { echo 'Base missing or output already exists' >&2; exit 1; }
[[ -z $(git -c "safe.directory=$project" -C "$project" status --porcelain) ]] || { echo 'Commit or discard source changes first' >&2; exit 1; }
expected=$(sed -n 's/^Base compressed SHA256: //p' "$lock")
printf '%s  %s\n' "$expected" "$base" | sha256sum -c -
for command in losetup parted partprobe e2fsck resize2fs xzcat git chroot sha256sum; do
    command -v "$command" >/dev/null || { echo "Missing build tool: $command" >&2; exit 1; }
done
available=$(df -Pk "$(dirname "$output")" | awk 'END {print $4}')
(( available >= 10485760 )) || { echo 'At least 10 GiB free scratch space required' >&2; exit 1; }

revision() { sed -n "s/^$1.*: //p" "$lock" | head -1; }
mpp_rev=$(revision 'Rockchip MPP')
rockchip_rev=$(revision 'gstreamer-rockchip')
uvc_rev=$(revision 'BELABOX gstlibuvch264src')
for sha in "$mpp_rev" "$rockchip_rev" "$uvc_rev"; do
    [[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid pinned source revision' >&2; exit 1; }
done

loop=''
root=''
cleanup() {
    local status=$?
    if [[ -n $root ]]; then
        for path in run dev/pts dev sys proc; do
            mountpoint -q "$root/$path" && umount -lf "$root/$path" || true
        done
        mountpoint -q "$root" && umount "$root" || true
        rmdir "$root" 2>/dev/null || true
    fi
    [[ -z $loop ]] || losetup -d "$loop" || true
    if (( status != 0 )); then
        echo 'Build failed; candidate image remains for diagnosis and must not be published.' >&2
    fi
}
trap cleanup EXIT

xzcat "$base" >"$output"
truncate -s 6442450944 "$output"
loop=$(losetup --find --show --partscan "$output")
parted -s -f "$loop" print >/dev/null
parted -s "$loop" resizepart 1 100%
partprobe "$loop"
udevadm settle
partition=${loop}p1
[[ -b $partition ]] || { echo 'Base root partition missing' >&2; exit 1; }
fsck_status=0
e2fsck -f -y "$partition" || fsck_status=$?
(( fsck_status <= 1 )) || { echo 'Base filesystem check failed' >&2; exit 1; }
resize2fs "$partition"
root=$(mktemp -d /tmp/osmo-public-root.XXXXXX)
mount "$partition" "$root"
for path in proc sys dev; do mount --rbind "/$path" "$root/$path"; done
mount -t tmpfs tmpfs "$root/run"
cp -L /etc/resolv.conf "$root/etc/resolv.conf.build"
rm -f "$root/etc/resolv.conf"
mv "$root/etc/resolv.conf.build" "$root/etc/resolv.conf"
mkdir -p "$root/opt/dji-build/project" "$root/usr/share/doc/dji-osmo2hdmi"
git -c "safe.directory=$project" -C "$project" archive HEAD | tar -x -C "$root/opt/dji-build/project"
git clone https://gitee.com/hermanchen82/mpp.git "$root/opt/dji-build/mpp"
git -C "$root/opt/dji-build/mpp" checkout --detach "$mpp_rev"
git clone https://github.com/Caesar-github/gstreamer-rockchip.git "$root/opt/dji-build/gstreamer-rockchip"
git -C "$root/opt/dji-build/gstreamer-rockchip" checkout --detach "$rockchip_rev"
git clone --recurse-submodules https://github.com/BELABOX/gstlibuvch264src.git "$root/opt/dji-build/gstlibuvch264src"
git -C "$root/opt/dji-build/gstlibuvch264src" checkout --detach "$uvc_rev"
git -C "$root/opt/dji-build/gstlibuvch264src" submodule update --init --recursive
chroot "$root" apt-get update
chroot "$root" /bin/bash /opt/dji-build/project/image/provision-rootfs.sh
chroot "$root" apt-get clean
printf 'Project build revision: %s\n' "$(git -c "safe.directory=$project" -C "$project" rev-parse HEAD)" >"$root/usr/share/doc/dji-osmo2hdmi/build-revision.txt"
chroot "$root" dpkg-query -W -f='${Package} ${Version}\n' >"$root/usr/share/doc/dji-osmo2hdmi/packages.txt"
for path in run dev/pts dev sys proc; do mountpoint -q "$root/$path" && umount -lf "$root/$path"; done
bash "$project/image/finalize-public-installer.sh" "$root" "$project"
rm -f "$root/etc/resolv.conf"
ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
(cd "$root" && sha256sum -c usr/share/doc/dji-osmo2hdmi/installer-critical.sha256 --quiet)
sync
umount "$root"
rmdir "$root"
root=''
e2fsck -f -n "$partition" | tee "${output}.fsck.txt"
losetup -d "$loop"
loop=''
sha256sum "$output" >"${output}.sha256"
xz -T2 -k -6 "$output"
sha256sum "${output}.xz" >"${output}.xz.sha256"
(( $(stat -c %s "${output}.xz") < 2147483648 )) || {
    echo 'Compressed candidate exceeds GitHub release asset limit' >&2; exit 1;
}
echo "Candidate ready: ${output}.xz"
