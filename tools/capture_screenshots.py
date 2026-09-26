#!/usr/bin/env python3
"""Build-independent deterministic Simulator screenshot capture for review runs."""
import argparse
import hashlib
import json
import os
import sys
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = {
    "atelie-colorir": ["home", "editor", "saved"],
    "crime-idle": ["home", "businesses", "missions"],
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
        run("xcrun", "simctl", "launch", udid, app["bundle"], f"--capture={screen}")
        time.sleep(2.5)
        destination = output / family / f"{screen}.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        run("xcrun", "simctl", "io", udid, "screenshot", str(destination))
        width, height = png_dimensions(destination)
        if min(width, height) < 800:
            raise RuntimeError(f"Screenshot resolution too small ({width}x{height}): {destination}")
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
