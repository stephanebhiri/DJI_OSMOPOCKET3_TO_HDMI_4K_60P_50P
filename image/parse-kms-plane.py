#!/usr/bin/env python3
"""Select a scalable Rockchip Esmart NV12 plane for a DRM CRTC mask."""

import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse-kms-plane.py <possible-crtcs-mask>", file=sys.stderr)
        return 2
    try:
        crtc_mask = int(sys.argv[1], 0)
    except ValueError:
        print("invalid CRTC mask", file=sys.stderr)
        return 2

    planes = []
    in_planes = False
    current = None
    prop = None
    for line in sys.stdin:
        if line.startswith("Planes:"):
            in_planes = True
            continue
        if not in_planes:
            continue
        match = re.match(
            r"^\s*(\d+)\s+\d+\s+\d+\s+\S+\s+\S+\s+\d+\s+(0x[0-9a-fA-F]+)\s*$",
            line,
        )
        if match:
            current = {
                "id": int(match.group(1)),
                "mask": int(match.group(2), 16),
                "nv12": False,
                "esmart": False,
                "scale": False,
                "max_width": 0,
                "max_height": 0,
            }
            planes.append(current)
            prop = None
            continue
        if current is None:
            continue
        if line.strip().startswith("formats:"):
            current["nv12"] = "NV12" in line.split()
        elif match := re.match(r"^\s*\d+\s+([A-Z_]+):\s*$", line):
            prop = match.group(1)
        elif prop == "NAME" and line.strip().startswith("values:"):
            current["esmart"] = bool(re.search(r"\bEsmart\d+-win\d+\b", line))
        elif prop == "FEATURE" and line.strip().startswith("values:"):
            current["scale"] = "scale=0x1" in line
        elif prop in ("INPUT_WIDTH", "INPUT_HEIGHT") and (
            match := re.match(r"^\s*values:\s*\d+\s+(\d+)\s*$", line)
        ):
            current["max_width" if prop == "INPUT_WIDTH" else "max_height"] = int(
                match.group(1)
            )

    for plane in planes:
        if (
            plane["nv12"]
            and plane["esmart"]
            and plane["scale"]
            and plane["max_width"] >= 3840
            and plane["max_height"] >= 2160
            and plane["mask"] & crtc_mask
        ):
            print(plane["id"])
            return 0
    print("no compatible 4K NV12 Esmart plane", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
