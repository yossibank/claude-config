#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

line="$root/scripts/ctx-status-line.py"
repo="$work/repo"
clone_with_origin "$repo"
git -C "$repo" checkout -q -b feat/x
echo '{"type":"assistant","message":{"usage":{"input_tokens":2000,"cache_read_input_tokens":110000}}}' >"$work/talk.jsonl"
echo '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":190000}}}' >>"$work/talk.jsonl"

input() {
    echo "{\"workspace\":{\"current_dir\":\"$repo\"},\"transcript_path\":\"$work/talk.jsonl\",\"model\":{\"id\":\"$1\",\"display_name\":\"Opus\"},\"cost\":{\"total_cost_usd\":1.234,\"total_lines_added\":12,\"total_lines_removed\":3}}"
}

out=$(input claude-opus-5-5 | python3 -I "$line")
check "status-line: フォルダとブランチを出す" grep -qF "📂 repo 🌿 feat/x · " <<<"$out"
check "status-line: サブエージェントを除いた文脈の量と割合を色付きで出す" grep -qF "🟡 112k（56%）" <<<"$out"
check "status-line: 費用と行の増減とモデルを出す" grep -qF "💰 \$1.23 · ✏️ +12/-3 · Opus" <<<"$out"
out=$(input 'claude-opus-5-5[1m]' | python3 -I "$line")
check "status-line: 1M の文脈のモデルは 100 万で割る" grep -qF "🟢 112k（11%）" <<<"$out"
out=$(echo "{\"cwd\":\"$work\"}" | python3 -I "$line")
check "status-line: リポジトリの外ではフォルダだけを出す" test "$out" == "📂 ${work##*/}"
out=$(echo "not json" | python3 -I "$line" 2>&1)
check "status-line: 壊れた入力では何も出さずに終わる" test -z "$out"
check "status-line: git のロックを作らない" test ! -e "$repo/.git/index.lock"

finish
