#!/bin/bash
set -euo pipefail

xcrun simctl list devices available -j | jq -r '[.devices[][] | select(.name | startswith("iPhone")) | .udid][0] // empty'
