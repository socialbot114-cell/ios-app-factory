#!/usr/bin/env python3
"""Select a stable preferred simulator, with an explicit installed-device fallback."""
import argparse
import json
import re
import subprocess


def version_key(runtime: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    return tuple(int(part or 0) for part in match.groups()) if match else (0,)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("family", choices=["iphone", "ipad"])
    parser.add_argument("--field", choices=["udid", "name", "runtime"], default="udid")
    args = parser.parse_args()
    result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"], check=True, text=True, capture_output=True)
    inventory = json.loads(result.stdout)
    devices = []
    for runtime, entries in inventory["devices"].items():
        if "iOS" not in runtime:
            continue
        for device in entries:
            if device.get("isAvailable") and device["name"].casefold().startswith(args.family):
                devices.append({**device, "runtime": runtime})
    if not devices:
        raise SystemExit(f"No available {args.family} simulator. Check `xcrun simctl list devices available`.")
    preferred = "iPhone 17" if args.family == "iphone" else "iPad Air 13-inch (M4)"
    device = next((item for item in devices if item["name"].casefold() == preferred.casefold()), None)
    if device is None:
        devices.sort(key=lambda item: (version_key(item["runtime"]), item["name"]), reverse=True)
        device = devices[0]
    print(device[args.field])


if __name__ == "__main__":
    main()
