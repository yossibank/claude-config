#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

python3 -I -c 'print("a" * 40000)' >"$work/big.md"
run ctx-limit-read 2 "ctx: 大きいファイルを範囲なしで読むと止める" "{\"tool_input\":{\"file_path\":\"$work/big.md\"}}"
run ctx-limit-read 0 "ctx: limit を付ければ通す" "{\"tool_input\":{\"file_path\":\"$work/big.md\",\"limit\":10}}"
run ctx-limit-read 0 "ctx: 壊れた入力では止めない" "not json"

finish
