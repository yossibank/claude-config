#!/bin/bash
set -euo pipefail

xcrun simctl list devices available -j | python3 -I -c 'import json, sys; ids = [d["udid"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["name"].startswith("iPhone")]; print(ids[0] if ids else "")'
