#!/usr/bin/env python3
"""Deterministic portfolio preflight; scans only this checked-out repository."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
apps = json.loads((ROOT / "tools/apps.json").read_text(encoding="utf-8"))
errors: list[str] = []

if len(apps) != 10:
    errors.append(f"Expected 10 apps, found {len(apps)}")
for field in ("slug", "scheme", "bundle", "name"):
    values = [app[field] for app in apps]
    if len(set(values)) != len(values):
        errors.append(f"Duplicate values in app registry field: {field}")

for app in apps:
    base = ROOT / "apps" / app["slug"]
    sources = list((base / "Sources").glob("*.swift"))
    tests = list((base / "Tests").glob("*.swift"))
    ui_tests = list((base / "UITests").glob("*.swift"))
    if not sources:
        errors.append(f"{app['slug']}: no Swift app source")
    if not tests:
        errors.append(f"{app['slug']}: no Swift tests")
    if not ui_tests:
        errors.append(f"{app['slug']}: no UI interaction tests")
    if sources and not any("@main" in source.read_text(encoding="utf-8") for source in sources):
        errors.append(f"{app['slug']}: no SwiftUI application entry point")

forbidden_suffixes = {".p8", ".p12", ".cer", ".key", ".mobileprovision", ".keystore"}
forbidden_names = {".env", "keystore.properties", "local.properties"}
for path in ROOT.rglob("*"):
    if not path.is_file() or ".git" in path.parts:
        continue
    if path.suffix.lower() in forbidden_suffixes or path.name in forbidden_names or path.name.startswith(".env."):
        errors.append(f"Forbidden credential/config file in repository: {path.relative_to(ROOT)}")

secret_patterns = [
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{30,}\b"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
]
for path in ROOT.rglob("*"):
    if not path.is_file() or ".git" in path.parts or path.suffix.lower() in {".png", ".jpg", ".jpeg", ".pdf", ".xcresult"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    if any(pattern.search(text) for pattern in secret_patterns):
        errors.append(f"Secret-like value detected in {path.relative_to(ROOT)}")

if errors:
    print("Factory validation failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"Factory validation passed: {len(apps)} apps, app/unit/UI-test sources present, no credential files or known secret patterns.")
