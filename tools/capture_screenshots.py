#!/usr/bin/env python3
"""Build-independent deterministic Simulator screenshot capture for review runs."""
import argparse
import hashlib
import json
import os
import sys
import struct
import subprocess
import time
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = {
    "atelie-colorir": ["home", "editor", "saved"],
    "crime-idle": ["home", "businesses", "story", "districts", "projects", "achievements"],
    "detetive-na-testa": ["home", "game", "result"],
    "manager-futebol": ["home", "table", "squad"],
    "meu-qr-pix": ["form", "qr", "history"],
    "leitor-pdf-bolso": ["library", "reader"],
    "brasilia-politica-contexto": ["home", "article", "saved"],
    "diario-sono": ["home", "active"],
    "quebra-cabecas": ["home", "board"],
}


def run(*args: str, check: bool = True, capture: bool = False) -> str:
    result = subprocess.run(args, check=False, text=True, stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.STDOUT if capture else None)
    if check and result.returncode:
        output = result.stdout or ""
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(args)}\n{output}")
    return result.stdout or ""


def find_device(family: str) -> tuple[str, str]:
    selector = ROOT / "tools" / "select_simulator.py"
    udid = run(sys.executable, str(selector), family, "--field", "udid", capture=True).strip()
    name = run(sys.executable, str(selector), family, "--field", "name", capture=True).strip()
    return udid, name


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"Not a PNG: {path}")
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def png_color_diversity(path: Path) -> int:
    data = path.read_bytes()
    offset = 8
    compressed = bytearray()
    width = height = bit_depth = color_type = None
    while offset + 12 <= len(data):
        length = int.from_bytes(data[offset:offset + 4], "big")
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or interlace != 0:
                return 0
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
        offset += length + 12
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if width is None or height is None or channels is None:
        return 0
    pixels = zlib.decompress(compressed)
    stride = width * channels
    previous = bytearray(stride)
    colors = set()
    step_x = max(width // 160, 1)
    step_y = max(height // 220, 1)

    def paeth(left: int, up: int, upper_left: int) -> int:
        prediction = left + up - upper_left
        distances = (abs(prediction - left), abs(prediction - up), abs(prediction - upper_left))
        return (left, up, upper_left)[distances.index(min(distances))]

    row_offset = 0
    for y in range(height):
        filter_type = pixels[row_offset]
        source = pixels[row_offset + 1:row_offset + stride + 1]
        row_offset += stride + 1
        row = bytearray(source)
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            up = previous[x]
            upper_left = previous[x - channels] if x >= channels else 0
            if filter_type == 1:
                row[x] = (row[x] + left) & 255
            elif filter_type == 2:
                row[x] = (row[x] + up) & 255
            elif filter_type == 3:
                row[x] = (row[x] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                row[x] = (row[x] + paeth(left, up, upper_left)) & 255
        if y % step_y == 0:
            for x in range(0, width, step_x):
                start = x * channels
                color = tuple(row[start:start + min(channels, 3)])
                colors.add(color)
                if len(colors) >= 256:
                    return len(colors)
        previous = row
    return len(colors)


def capture_device(udid: str, device_name: str, family: str, app: dict, app_path: Path, output: Path) -> list[dict]:
    run("xcrun", "simctl", "boot", udid, check=False)
    run("xcrun", "simctl", "bootstatus", udid, "-b")
    run("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged",
        "--batteryLevel", "100", "--wifiMode", "active", "--wifiBars", "3", "--cellularMode", "active", "--cellularBars", "4", check=False)
    run("xcrun", "simctl", "ui", udid, "appearance", "light", check=False)
    records = []
    seen_hashes = set()
    for screen in CAPTURES[app["slug"]]:
        run("xcrun", "simctl", "terminate", udid, app["bundle"], check=False)
        run("xcrun", "simctl", "uninstall", udid, app["bundle"], check=False)
        run("xcrun", "simctl", "install", udid, str(app_path))
        launch_arguments = ("--uitesting", f"--capture={screen}")
        run("xcrun", "simctl", "launch", udid, app["bundle"], *launch_arguments)
        destination = output / family / f"{screen}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        diversity = 0
        for attempt in range(1, 5):
            time.sleep(3)
            run("xcrun", "simctl", "io", udid, "screenshot", str(destination))
            diversity = png_color_diversity(destination)
            if diversity >= 80:
                break
            if attempt < 4:
                run("xcrun", "simctl", "terminate", udid, app["bundle"], check=False)
                time.sleep(1)
                run("xcrun", "simctl", "launch", udid, app["bundle"], *launch_arguments)
        width, height = png_dimensions(destination)
        if min(width, height) < 800:
            raise RuntimeError(f"Screenshot resolution too small ({width}x{height}): {destination}")
        if diversity < 80:
            raise RuntimeError(f"Screenshot appears blank or still launching (color diversity={diversity}): {destination}")
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        if digest in seen_hashes:
            raise RuntimeError(f"Duplicate screenshot across requested states; capture route may not have changed: {destination}")
        seen_hashes.add(digest)
        records.append({"app": app["slug"], "name": app["name"], "device": device_name,
                        "family": family, "screen": screen, "file": str(destination.relative_to(output)),
                        "width": width, "height": height, "sha256": digest})
        run("xcrun", "simctl", "terminate", udid, app["bundle"], check=False)
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--slug", required=True)
    parser.add_argument("--scheme", required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--derived-data", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    apps = json.loads((ROOT / "tools/apps.json").read_text(encoding="utf-8"))
    app = next((item for item in apps if item["slug"] == args.slug), None)
    if app is None or app["scheme"] != args.scheme or app["bundle"] != args.bundle:
        raise SystemExit("App identity does not match tools/apps.json")
    app_path = Path(args.derived_data) / "Build/Products/Debug-iphonesimulator" / f"{args.scheme}.app"
    if not app_path.is_dir():
        raise SystemExit(f"Simulator app not found: {app_path}")
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for family in ("iphone", "ipad"):
        udid, name = find_device(family)
        records.extend(capture_device(udid, name, family, app, app_path, output))
    manifest = {"app": app, "commit": os.environ.get("GITHUB_SHA", "local"),
                "run_id": os.environ.get("GITHUB_RUN_ID", "local"), "screenshots": records}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Captured {len(records)} screenshots for {app['name']}.")


if __name__ == "__main__":
    main()
