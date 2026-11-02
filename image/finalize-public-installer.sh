#!/usr/bin/env bash
# Finish a mounted, clean Armbian rootfs as a credential-free SD installer.
set -Eeuo pipefail

root=${1:?mounted root filesystem required}
project=${2:?project source directory required}
[[ -f $root/etc/os-release && -f $root/boot/armbianEnv.txt ]] || {
    echo 'Not an Armbian root filesystem' >&2; exit 1;
}
grep -q 'VERSION_CODENAME=noble' "$root/etc/os-release"
[[ -f $project/image/osmo-install-emmc.sh ]] || { echo 'Missing installer source' >&2; exit 1; }

install -m 755 "$project/image/osmo-install-emmc.sh" "$root/usr/local/sbin/osmo-install-emmc.sh"
install -m 644 "$project/image/osmo-install-emmc.service" "$root/etc/systemd/system/osmo-install-emmc.service"
units=$root/etc/systemd/system/multi-user.target.wants
mkdir -p "$units" "$root/usr/share/doc/dji-osmo2hdmi"
for name in dji-h264-stream osmo-hdmi50 dji-hdmi-audio dji-install-to-nvme ssh sshd armbian-resize-filesystem armbian-firstrun; do
    rm -f "$units/$name.service"
done
# Armbian installs its resize unit under basic.target, before the installer
# starts. It must stay disabled on SD so the copied region remains 6 GiB.
rm -f "$root/etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service"
ln -sfn /dev/null "$root/etc/systemd/system/armbian-resize-filesystem.service"
rm -f "$root/etc/systemd/system/sockets.target.wants/ssh.socket"
for name in ssh.service sshd.service ssh.socket; do
    ln -sfn /dev/null "$root/etc/systemd/system/$name"
done
# The clean Armbian image still ships a console autologin and the
# .not_logged_in_yet marker. Together they launch an interactive root-password
# wizard, even when armbian-firstrun.service is disabled.
rm -f "$root/root/.not_logged_in_yet" \
    "$root/etc/profile.d/armbian-check-first-login.sh" \
    "$root/etc/profile.d/armbian-check-first-login-reboot.sh"
rm -f "$root/etc/systemd/system/getty.target.wants/getty@tty1.service" \
    "$root/etc/systemd/system/getty.target.wants/serial-getty@ttyFIQ0.service"
rm -rf "$root/etc/systemd/system/getty@.service.d" \
    "$root/etc/systemd/system/serial-getty@.service.d"
ln -sfn /dev/null "$root/etc/systemd/system/getty@.service"
ln -sfn /dev/null "$root/etc/systemd/system/serial-getty@.service"
ln -sfn ../osmo-install-emmc.service "$units/osmo-install-emmc.service"

# No reusable credentials or device identity may be inherited by a public image.
if [[ -f $root/etc/shadow ]]; then
    awk -F: 'BEGIN { OFS=":" } { $2="!"; print }' "$root/etc/shadow" >"$root/etc/shadow.public"
    chmod 600 "$root/etc/shadow.public"
    mv "$root/etc/shadow.public" "$root/etc/shadow"
fi
rm -rf "$root/root/.ssh" "$root"/home/*/.ssh
rm -f "$root/root/.bash_history" "$root/var/lib/systemd/random-seed"
rm -f "$root"/etc/ssh/ssh_host_*
rm -f "$root/etc/machine-id" "$root/var/lib/dbus/machine-id"
: >"$root/etc/machine-id"
rm -rf "$root"/var/log/* "$root"/var/cache/apt/archives/*.deb "$root"/var/lib/apt/lists/*
rm -rf "$root/opt/dji-build"
rm -rf "$root/var/lib/osmo-emmc-install"
printf 'osmo2hdmi\n' >"$root/etc/hostname"
printf '%s\n' \
    'Public Orange Pi 5 Plus microSD to eMMC installer' \
    'No login or SSH enabled by default' \
    'Pocket 3 video and HDMI audio start after installation and SD removal' \
    >"$root/usr/share/doc/dji-osmo2hdmi/device-build.txt"

critical=(
    boot/armbianEnv.txt
    usr/local/bin/dji-stream.sh
    root/.spspps/0
    usr/local/bin/osmo-hdmi50.sh
    usr/local/bin/dji-hdmi-audio.sh
    usr/local/bin/parse-hdmi-mode.sh
    usr/local/bin/parse-encoder-mask.sh
    usr/local/bin/parse-kms-plane.py
    usr/local/sbin/osmo-install-emmc.sh
    etc/systemd/system/dji-h264-stream.service
    etc/systemd/system/osmo-hdmi50.service
    etc/systemd/system/dji-hdmi-audio.service
    etc/systemd/system/osmo-install-emmc.service
)
for file in "${critical[@]}"; do
    [[ -f $root/$file ]] || { echo "Missing critical file: $file" >&2; exit 1; }
done
manifest=$root/usr/share/doc/dji-osmo2hdmi/installer-critical.sha256
(cd "$root" && sha256sum "${critical[@]}" >"$manifest")
echo 'Public SD installer enabled; runtime starts from eMMC only.'
