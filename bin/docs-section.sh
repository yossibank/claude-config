#!/bin/bash
set -euo pipefail

exec python3 -I "$(dirname "$0")/../lib/bin/docs_section/sections.py" "$@"
