#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

count="$root/skills/ctx-report/scripts/count-tokens.py"
export CC_PROJECTS_DIR="$work/projects"
session="$CC_PROJECTS_DIR/p1/s1"
mkdir -p "$session/subagents"

usage() {
    echo "{\"type\":\"assistant\",\"requestId\":\"$1\",\"timestamp\":\"${3:-2026-09-10T02:00:00.000Z}\",\"message\":{\"id\":\"$1\",\"usage\":$2}}"
}

{
    echo '{"type":"custom-title","customTitle":"作業 A"}'
    echo '{"type":"user","timestamp":"2026-09-10T01:00:00.000Z","cwd":"/x/app/.claude/worktrees/w1","gitBranch":"feat/a"}'
    usage r1 '{"input_tokens":100000,"cache_read_input_tokens":1000000,"output_tokens":20000}'
    usage r1 '{"input_tokens":100000,"cache_read_input_tokens":1000000,"output_tokens":20000}'
} >"$session.jsonl"
usage r2 '{"input_tokens":100000}' >"$session/subagents/a1.jsonl"
echo '{"type":"user","timestamp":"2026-08-31T01:00:00.000Z"}' >"$CC_PROJECTS_DIR/p1/old.jsonl"
usage r3 '{"input_tokens":900000}' 2026-08-31T02:00:00.000Z >>"$CC_PROJECTS_DIR/p1/old.jsonl"

span="$CC_PROJECTS_DIR/p3/span.jsonl"
mkdir -p "$CC_PROJECTS_DIR/p3/span/subagents"
{
    echo '{"type":"user","timestamp":"2026-10-30T01:00:00.000Z","cwd":"/x/span/.claude/worktrees/w3","gitBranch":"feat/span"}'
    echo '{"type":"custom-title","customTitle":"月またぎ"}'
    echo '{"type":"assistant","requestId":"s1","timestamp":"2026-10-30T02:00:00.000Z","message":{"id":"s1","usage":{"input_tokens":900000}}}'
    echo '{"type":"assistant","requestId":"s2","timestamp":"2026-10-31T16:00:00.000Z","message":{"id":"s2","usage":{"input_tokens":200000}}}'
    echo '{"type":"assistant","requestId":"s3","timestamp":"2026-11-02T01:00:00.000Z","message":{"id":"s3","usage":{"input_tokens":300000}}}'
    echo '{"type":"assistant","requestId":"s4","timestamp":"2026-11-30T15:00:00.000Z","message":{"id":"s4","usage":{"input_tokens":700000}}}'
} >"$span"
{
    echo '{"type":"assistant","requestId":"a1","timestamp":"2026-10-30T03:00:00.000Z","message":{"id":"a1","usage":{"input_tokens":800000}}}'
    echo '{"type":"assistant","requestId":"a2","timestamp":"2026-11-02T03:00:00.000Z","message":{"id":"a2","usage":{"input_tokens":100000}}}'
} >"$CC_PROJECTS_DIR/p3/span/subagents/a.jsonl"
echo '{"type":"user","cwd":"/x/nostamp"}' >"$CC_PROJECTS_DIR/p3/nostamp.jsonl"
echo '{"type":"assistant","requestId":"n1","message":{"id":"n1","usage":{"input_tokens":5}}}' >>"$CC_PROJECTS_DIR/p3/nostamp.jsonl"

expect "NG 使い方" "count-tokens: 引数が無ければ NG" python3 -I "$count"
expect "NG 月は YYYY-MM で書く" "count-tokens: 月の形が違えば NG" python3 -I "$count" 2026-13
expect "NG 件数は数字で書く" "count-tokens: 件数が数字でなければ NG" python3 -I "$count" 2026-09 x
CC_PROJECTS_DIR="$work/none" expect "の会話の記録が無い" "count-tokens: 会話の記録が無ければ NG" python3 -I "$count" 2026-09

out=$(python3 -I "$count" 2026-09)
check "count-tokens: その月に始まった会話だけを数える" grep -q '^会話は 1 件' <<<"$out"
check "count-tokens: 同じ要求を 2 回数えず、サブエージェントを足して入力換算で並べる" \
    grep -qxF '| 09-10 | app @feat/a | 作業 A | 1 | 40 | 25% | 110.0 | 2 |' <<<"$out"

other="$work/other/p2/s2.jsonl"
mkdir -p "$(dirname "$other")"
{
    echo "{\"type\":\"user\",\"timestamp\":\"2026-09-11T01:00:00.000Z\",\"cwd\":\"$HOME/.claude/worktrees/tool/feat-b\",\"gitBranch\":\"feat/b\"}"
    usage r4 '{"input_tokens":100}' 2026-09-11T02:00:00.000Z
} >"$other"
out=$(CC_PROJECTS_DIR="$work/other" python3 -I "$count" 2026-09)
check "count-tokens: ~/.claude/worktrees の下の作業は、リポジトリの名前を場所にする" grep -qF '| tool @feat/b |' <<<"$out"

out=$(python3 -I "$count" 2026-11)
check "count-tokens: 前の月に始まった会話は、その月の要求だけを数える" \
    grep -qxF '| 11-01 | span @feat/span | 月またぎ | 2 | 60 | 17% | 25.0 | 0 |' <<<"$out"
check "count-tokens: 月は日本時間で分け、会話の月またぎで 2 つの月に数えない" grep -q '^会話は 1 件' <<<"$out"
out=$(python3 -I "$count" 2026-10)
check "count-tokens: 次の月に続く会話は、その月の要求だけを数える" \
    grep -qxF '| 10-30 | span @feat/span | 月またぎ | 1 | 170 | 47% | 90.0 | 0 |' <<<"$out"

finish
