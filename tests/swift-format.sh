#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

run swift-format 0 "swift: .swiftformat が無ければ何もしない" "{\"tool_input\":{\"file_path\":\"$swift\"}}"

finish
