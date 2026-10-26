#!/usr/bin/env bash
set -euo pipefail
root=${1:?mounted public root filesystem required}
[[ -f $root/etc/os-release ]] || exit 1
units=$root/etc/systemd/system/multi-user.target.wants
[[ -L $units/osmo-install-emmc.service ]]
for name in dji-h264-stream osmo-hdmi50 dji-hdmi-audio ssh sshd armbian-firstrun armbian-resize-filesystem; do
    [[ ! -e $units/$name.service ]]
done
for name in ssh.service sshd.service ssh.socket; do
    [[ $(readlink "$root/etc/systemd/system/$name") == /dev/null ]]
done
[[ ! -s $root/etc/machine-id && ! -e $root/root/.ssh && ! -e $root/opt/dji-build ]]
[[ ! -e $root/var/lib/osmo-emmc-install/state ]]
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
