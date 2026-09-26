#!/usr/bin/env python3
import json
import sys
from pathlib import Path

apps = json.loads(Path("tools/apps.json").read_text(encoding="utf-8"))
requested = sys.argv[1] if len(sys.argv) > 1 else "all"
selected = apps if requested in ("", "all") else [app for app in apps if app["slug"] == requested]
if not selected:
    raise SystemExit(f"Unknown app selection: {requested}")
print(json.dumps({"include": selected}, separators=(",", ":")))
