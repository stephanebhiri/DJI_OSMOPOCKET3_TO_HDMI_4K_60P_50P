#!/usr/bin/env bash
set -euo pipefail
root=${1:?mounted public root filesystem required}
[[ -f $root/etc/os-release ]] || exit 1
units=$root/etc/systemd/system/multi-user.target.wants
[[ -L $units/osmo-install-emmc.service ]] || { echo 'Installer unit not enabled' >&2; exit 1; }
for name in dji-h264-stream osmo-hdmi50 dji-hdmi-audio ssh sshd armbian-firstrun armbian-resize-filesystem; do
    [[ ! -e $units/$name.service ]] || { echo "Unexpected enabled service: $name" >&2; exit 1; }
done
for name in ssh.service sshd.service ssh.socket; do
    [[ $(readlink "$root/etc/systemd/system/$name") == /dev/null ]] || { echo "SSH not masked: $name" >&2; exit 1; }
done
[[ ! -s $root/etc/machine-id && ! -e $root/root/.ssh && ! -e $root/opt/dji-build ]] || { echo 'Private identity or build sources retained' >&2; exit 1; }
[[ ! -e $root/var/lib/osmo-emmc-install/state ]] || { echo 'Installer state retained' >&2; exit 1; }
[[ ! -e $root/root/.not_logged_in_yet ]] || { echo 'Armbian first-login marker retained' >&2; exit 1; }
[[ ! -e $root/etc/profile.d/armbian-check-first-login.sh ]] || { echo 'First-login hook retained' >&2; exit 1; }
for name in getty@.service serial-getty@.service; do
    [[ $(readlink "$root/etc/systemd/system/$name") == /dev/null ]] || {
        echo "Interactive console login remains enabled: $name" >&2; exit 1;
    }
done
if grep -R -q -- '--autologin root' "$root/etc/systemd/system"; then
    echo 'Root console autologin retained' >&2; exit 1
fi
if find "$root/etc/ssh" -maxdepth 1 -name 'ssh_host_*' -print -quit | grep -q .; then
    echo 'SSH host key retained' >&2; exit 1
fi
if awk -F: '$2 != "!" { found=1 } END { exit !found }' "$root/etc/shadow"; then
    echo 'Unlocked local account retained' >&2; exit 1
fi
if grep -REq '192[.]168[.]75[.]|stephane' \
    "$root/usr/share/doc/dji-osmo2hdmi" "$root/etc/hostname" "$root/etc/hosts"; then
    echo 'Personal identifier retained' >&2; exit 1
fi
(cd "$root" && sha256sum -c usr/share/doc/dji-osmo2hdmi/installer-critical.sha256 --quiet)
echo 'Public rootfs audit: PASS'
