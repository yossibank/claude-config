#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

count="$root/skills/ctx-report/scripts/count-tokens.py"
export CLAUDE_PROJECTS="$work/projects"
session="$CLAUDE_PROJECTS/p1/s1"
mkdir -p "$session/subagents"

usage() {
    echo "{\"type\":\"assistant\",\"requestId\":\"$1\",\"message\":{\"id\":\"$1\",\"usage\":$2}}"
}

{
    echo '{"type":"custom-title","customTitle":"作業 A"}'
    echo '{"type":"user","timestamp":"2026-09-10T01:00:00.000Z","cwd":"/x/app/.claude/worktrees/w1","gitBranch":"feat/a"}'
    usage r1 '{"input_tokens":100000,"cache_read_input_tokens":1000000,"output_tokens":20000}'
    usage r1 '{"input_tokens":100000,"cache_read_input_tokens":1000000,"output_tokens":20000}'
} >"$session.jsonl"
usage r2 '{"input_tokens":100000}' >"$session/subagents/a1.jsonl"
echo '{"type":"user","timestamp":"2026-08-31T01:00:00.000Z"}' >"$CLAUDE_PROJECTS/p1/old.jsonl"
usage r3 '{"input_tokens":900000}' >>"$CLAUDE_PROJECTS/p1/old.jsonl"

expect "NG 使い方" "count-tokens: 引数が無ければ NG" python3 -I "$count"
expect "NG 月は YYYY-MM で書く" "count-tokens: 月の形が違えば NG" python3 -I "$count" 2026-13
expect "NG 件数は数字で書く" "count-tokens: 件数が数字でなければ NG" python3 -I "$count" 2026-09 x
CLAUDE_PROJECTS="$work/none" expect "の会話の記録が無い" "count-tokens: 会話の記録が無ければ NG" python3 -I "$count" 2026-09

out=$(python3 -I "$count" 2026-09)
check "count-tokens: その月に始まった会話だけを数える" grep -q '^会話は 1 件' <<<"$out"
check "count-tokens: 同じ要求を 2 回数えず、サブエージェントを足して入力換算で並べる" \
    grep -qxF '| 09-10 | app @feat/a | 作業 A | 1 | 40 | 25% | 110.0 | 2 |' <<<"$out"

finish
