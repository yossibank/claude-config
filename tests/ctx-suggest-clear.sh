#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

usage='{"type":"assistant","message":{"usage":{"input_tokens":1,"cache_read_input_tokens":250000}}}'
echo "$usage" >"$work/long.jsonl"
out=$(echo "{\"session_id\":\"c1\",\"transcript_path\":\"$work/long.jsonl\"}" | bash "$hooks" ctx-suggest-clear)
check "ctx: 20 万トークンを超えたら区切りを勧める" grep -q systemMessage <<<"$out"
out=$(echo "{\"session_id\":\"c1\",\"transcript_path\":\"$work/long.jsonl\"}" | bash "$hooks" ctx-suggest-clear)
check "ctx: 同じ段では 2 回勧めない" test -z "$out"
touch -t 202001010000 "${TMPDIR}claude-suggest-clear/old"
echo "{\"session_id\":\"c2\",\"transcript_path\":\"$work/long.jsonl\"}" | bash "$hooks" ctx-suggest-clear >/dev/null
check "ctx: 勧めた記録を残す時に、古い記録を消す" test ! -e "${TMPDIR}claude-suggest-clear/old"
run ctx-suggest-clear 0 "ctx: 壊れた入力でも落ちない" "not json" pr
run ctx-suggest-clear 1 "ctx: 知らないモードは止めずに知らせる" "{}" prr

finish
