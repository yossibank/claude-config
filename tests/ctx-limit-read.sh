#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/support/assert.sh"
source "$(dirname "$0")/support/fixtures.sh"
source "$(dirname "$0")/support/hook_fixtures.sh"
STOP="丸ごと読まない"

head -c 40000 /dev/zero | tr '\0' a >"$work/big.md"
run ctx-limit-read 2 "ctx: 大きいファイルを範囲なしで読むと止める" "$(file_call "$work/big.md")"
run ctx-limit-read 0 "ctx: limit を付ければ通す" "$(file_call "$work/big.md" | jq -c '.tool_input.limit = 10')"
run ctx-limit-read 0 "ctx: 壊れた入力では止めない" "not json"
cp "$work/big.md" "$work/big.JSONL"
run ctx-limit-read 2 "ctx: 会話の記録も、拡張子の大文字と小文字を問わず止める" "$(file_call "$work/big.JSONL")"

head -c 30000 /dev/zero | tr '\0' a >"$work/limit.md"
run ctx-limit-read 0 "ctx: 30_000 バイトちょうどは通す" "$(file_call "$work/limit.md")"
head -c 30001 /dev/zero | tr '\0' a >"$work/over.md"
run ctx-limit-read 2 "ctx: 30_000 バイトを 1 つ超えたら止める" "$(file_call "$work/over.md")"
cp "$work/big.md" "$work/big.bin"
run ctx-limit-read 0 "ctx: 対象外の拡張子は大きくても通す" "$(file_call "$work/big.bin")"
run ctx-limit-read 0 "ctx: 無いファイルは通す" "$(file_call "$work/none.md")"

finish
