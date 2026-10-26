#!/usr/bin/awk -f

# Read `modetest -M rockchip -c` and emit the HDMI-A-2 connector ID and the
# EDID mode index for 1920x1080i50. Both IDs can change between systems.
/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+connected[[:space:]]+HDMI-A-2([[:space:]]|$)/ {
    connector = $1
    in_target = 1
    next
}

in_target && /^[[:space:]]*#[0-9]+[[:space:]]+1920x1080i[[:space:]]+50[.]00([[:space:]]|$)/ {
    sub(/^#/, "", $1)
    print connector, $1
    found = 1
    exit
}

in_target && /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+(connected|disconnected)[[:space:]]/ {
    exit
}

END {
    if (!found) exit 1
}
