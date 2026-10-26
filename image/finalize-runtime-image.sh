#!/usr/bin/env bash
# Finish a mounted, provisioned Orange Pi 5 Plus image for this device.
set -Eeuo pipefail

root=${1:?mounted root filesystem required}
pubkey=${2:?maintenance public key required}
project=${3:?project source directory required}

[[ $EUID == 0 ]] || { echo 'Run as root' >&2; exit 1; }
[[ -f $root/etc/os-release && -f $root/boot/armbianEnv.txt ]] || {
    echo 'Not an Armbian root filesystem' >&2
    exit 1
}
grep -q 'VERSION_CODENAME=noble' "$root/etc/os-release"
[[ -f $pubkey && -f $project/image/osmo-install-emmc.sh ]] || {
    echo 'Missing public key or installer source' >&2
    exit 1
}

install -m 755 "$project/image/osmo-install-emmc.sh" "$root/usr/local/sbin/osmo-install-emmc.sh"
install -m 644 "$project/image/osmo-install-emmc.service" "$root/etc/systemd/system/osmo-install-emmc.service"

# Keep the 6 GiB partition unchanged: the eMMC installer verifies this size
# before copying it, and Armbian's first-boot resize would break that check.
chroot "$root" systemctl disable armbian-resize-filesystem.service armbian-firstrun.service
chroot "$root" systemctl disable osmo-install-emmc.service dji-install-to-nvme.service >/dev/null 2>&1 || true
chroot "$root" systemctl enable osmo-hdmi50.service dji-h264-stream.service dji-hdmi-audio.service ssh.service

install -d -m 700 "$root/root/.ssh"
install -m 600 "$pubkey" "$root/root/.ssh/authorized_keys"
install -d -m 755 "$root/etc/ssh/sshd_config.d"
cat >"$root/etc/ssh/sshd_config.d/99-osmo2hdmi.conf" <<'SSH'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
SSH
chroot "$root" passwd -l root >/dev/null
install -d -m 755 "$root/run/sshd"
chroot "$root" /usr/sbin/sshd -t

printf 'osmo2hdmi\n' >"$root/etc/hostname"
if ! grep -qE '^127[.]0[.]1[.]1[[:space:]]+osmo2hdmi([[:space:]]|$)' "$root/etc/hosts"; then
    printf '127.0.1.1 osmo2hdmi\n' >>"$root/etc/hosts"
fi
printf '%s\n' 'BELABOX Orange Pi 5 Plus personal image, 2026-10-26' \
    'Runtime: Pocket 3 4K50 to HDMI-A-2 1080i50 with HDMI audio' \
    'eMMC installer: present but disabled' \
    >"$root/usr/share/doc/dji-osmo2hdmi/device-build.txt"

chroot "$root" apt-get clean
rm -rf "$root/var/lib/apt/lists/"* "$root/opt/dji-build"
rm -f "$root/etc/machine-id" "$root/var/lib/dbus/machine-id"
: >"$root/etc/machine-id"
rm -f "$root/etc/resolv.conf"
ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
sync
