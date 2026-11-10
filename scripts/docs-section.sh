#!/bin/bash
set -euo pipefail

exec python3 -I "$(dirname "$0")/../lib/docs_section.py" "$@"
