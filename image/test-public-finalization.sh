#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
root=$tmp/root
mkdir -p "$root"/{etc/systemd/system/multi-user.target.wants,etc/systemd/system/getty.target.wants,etc/systemd/system/getty@.service.d,etc/systemd/system/serial-getty@.service.d,etc/ssh,root/.ssh,var/log,usr/local/bin,usr/local/sbin,usr/share/doc/dji-osmo2hdmi,boot}
printf 'VERSION_CODENAME=noble\n' >"$root/etc/os-release"
printf '127.0.0.1 localhost\n' >"$root/etc/hosts"
printf 'root:$6$personal-hash:1:0:99999:7:::\n' >"$root/etc/shadow"
printf 'private\n' >"$root/root/.ssh/authorized_keys"
touch "$root/root/.not_logged_in_yet"
printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root %%I $TERM\n' >"$root/etc/systemd/system/getty@.service.d/override.conf"
printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root %%I $TERM\n' >"$root/etc/systemd/system/serial-getty@.service.d/override.conf"
ln -s /lib/systemd/system/getty@.service "$root/etc/systemd/system/getty.target.wants/getty@tty1.service"
ln -s /lib/systemd/system/serial-getty@.service "$root/etc/systemd/system/getty.target.wants/serial-getty@ttyFIQ0.service"
printf 'oldhost\n' >"$root/etc/ssh/ssh_host_ed25519_key"
printf 'old-id\n' >"$root/etc/machine-id"
printf 'private log\n' >"$root/var/log/auth.log"
printf 'extraargs=usbcore.quirks=2ca3:0023:i cma=256M\n' >"$root/boot/armbianEnv.txt"
for name in dji-stream.sh osmo-hdmi50.sh dji-hdmi-audio.sh parse-hdmi-mode.sh parse-encoder-mask.sh parse-kms-plane.py; do
    printf 'test source %s\n' "$name" >"$root/usr/local/bin/$name"
done
for name in dji-h264-stream osmo-hdmi50 dji-hdmi-audio ssh; do
    printf 'unit\n' >"$root/etc/systemd/system/$name.service"
    ln -s "../$name.service" "$root/etc/systemd/system/multi-user.target.wants/$name.service"
done

bash "$(dirname "$0")/finalize-public-installer.sh" "$root" "$(cd "$(dirname "$0")/.." && pwd)"
units=$root/etc/systemd/system/multi-user.target.wants
[[ -L $units/osmo-install-emmc.service ]] || { echo 'Installer not enabled' >&2; exit 1; }
[[ ! -e $units/dji-h264-stream.service && ! -e $units/osmo-hdmi50.service && ! -e $units/dji-hdmi-audio.service ]] || { echo 'Runtime enabled on SD' >&2; exit 1; }
[[ ! -e $units/ssh.service && $(readlink "$root/etc/systemd/system/ssh.service") == /dev/null ]] || { echo 'SSH enabled' >&2; exit 1; }
[[ ! -e $root/root/.ssh && ! -e $root/etc/ssh/ssh_host_ed25519_key ]] || { echo 'SSH keys retained' >&2; exit 1; }
[[ ! -s $root/etc/machine-id && ! -e $root/var/log/auth.log ]] || { echo 'Device identity retained' >&2; exit 1; }
[[ $(cut -d: -f2 "$root/etc/shadow") == '!' ]] || { echo 'Root account unlocked' >&2; exit 1; }
[[ ! -e $root/root/.not_logged_in_yet ]] || { echo 'Armbian first-login marker retained' >&2; exit 1; }
[[ $(readlink "$root/etc/systemd/system/getty@.service") == /dev/null ]] || { echo 'Console login not disabled' >&2; exit 1; }
[[ $(readlink "$root/etc/systemd/system/serial-getty@.service") == /dev/null ]] || { echo 'Serial login not disabled' >&2; exit 1; }
[[ ! -e $root/etc/systemd/system/getty@.service.d/override.conf ]] || { echo 'Console autologin retained' >&2; exit 1; }
[[ ! -e $root/etc/systemd/system/serial-getty@.service.d/override.conf ]] || { echo 'Serial autologin retained' >&2; exit 1; }
[[ -s $root/usr/share/doc/dji-osmo2hdmi/installer-critical.sha256 ]] || { echo 'Critical-file manifest missing' >&2; exit 1; }
(cd "$root" && sha256sum -c usr/share/doc/dji-osmo2hdmi/installer-critical.sha256 --quiet)
bash "$(dirname "$0")/audit-public-rootfs.sh" "$root"
echo 'Public installer finalization: PASS'
