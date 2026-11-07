#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

log="$work/t.jsonl"
: >"$log"
run rules-require-read 2 "rules: 読まずに Swift を編集すると止まる" "$(edit s1 main "$log" "$swift")"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s1 main "$name"; done
run rules-require-read 0 "rules: Read した後は通る" "$(edit s1 main "$log" "$swift")"
sleep 1
echo "{\"type\":\"system\",\"subtype\":\"compact_boundary\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" >>"$log"
sleep 1
run rules-require-read 2 "rules: 読んだ後に圧縮があれば、また止まる" "$(edit s1 main "$log" "$swift")"
auto="$HOME/.claude/rules"
echo "{\"type\":\"attachment\",\"attachment\":{\"type\":\"instructions\",\"files\":[{\"path\":\"$auto/code-comments.md\"},{\"path\":\"$auto/swift-core.md\"},{\"path\":\"$auto/swift-ui.md\"}]}}" >>"$log"
run rules-require-read 0 "rules: 圧縮の後に自動で読み込まれた印があれば通る" "$(edit s1 main "$log" "$swift")"
run rules-require-read 2 "rules: まだ無いフォルダへの編集も止める" "$(edit s4 main "$work/none.jsonl" "$app/ios/Features/New/Deep/NewView.swift")"
run rules-require-read 0 "rules: 当たる rules が無いファイルは止めない" "$(edit s1 main "$log" "$app/data.json")"
echo '# メモ' >"$work/memo.md"
run rules-require-read 0 "rules: git の外のファイル（メモリ・プラン）は止めない" "$(edit s1 main "$log" "$work/memo.md")"
: >"$work/empty.jsonl"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s3 main "$name" & done
wait
run rules-require-read 0 "rules: 同時に Read しても取りこぼさない" "$(edit s3 main "$work/empty.jsonl" "$swift")"
fresh="$work/t2.jsonl"
: >"$fresh"
for name in docs-core.md docs-app.md docs-human.md; do read_rule s2 main "$name"; done
run rules-require-read 2 "rules: サブエージェントは親の記録を使わない" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
for name in docs-core.md docs-app.md docs-human.md; do read_rule s2 a1 "$name"; done
run rules-require-read 0 "rules: サブエージェントが自分で読めば通る" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
CC_HOOKS_OFF="pr-gate rules-require-read" run rules-require-read 0 "rules: CC_HOOKS_OFF に名前があれば止めない" "$(edit s9 main "$fresh" "$swift")"
run rules-require-read 0 "rules: 壊れた入力では止めない" "not json"
odd="$work/odd.jsonl"
printf '%s\n' '{"type":"x","note":"instructions","attachment":"/rules/"}' '{"type":"attachment","attachment":{"type":"instructions","files":["/rules/x.md"]}}' >"$odd"
run rules-require-read 2 "rules: 記録の attachment が辞書でなくても落ちずに止める" "$(edit s8 main "$odd" "$swift")"
run hooks-runner 1 "run.sh: hooks/ に無い名前は NG で止める" "{}"
off=$' x1,x2\tx3\nx4 ,, x5,'
out=$(echo '{}' | CC_HOOKS_OFF="$off" bash "$hooks" rules-require-read 2>&1)
match "rules: run.sh は CC_HOOKS_OFF を空白・カンマ・タブ・改行で名前に分ける" "$out" "*hooks/ に無い名前がある: x1 x2 x3 x4 x5"
mkdir "$work/probe"
cp "$hooks" "$work/probe/run.sh"
cat >"$work/probe/probe.py" <<PY
import sys
sys.path.insert(0, "$root/lib")
from hook_io import hook_off
print(" ".join(name for name in ["x", "x1", "x2", "x3", "x4", "x5", "x6", "x1,x2", "x4 "] if hook_off(name)))
PY
out=$(CC_HOOKS_OFF="$off"$'\r'x6 bash "$work/probe/run.sh" probe 2>/dev/null)
match "rules: hook_io の hook_off は run.sh が分けた名前の並びを使い、\\r も区切る" "$out" "x1 x2 x3 x4 x5 x6"

inc="$work/inc.jsonl"
: >"$inc"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s5 main "$name"; done
run rules-require-read 0 "rules: 記録が空でも読んだ rules で通る" "$(edit s5 main "$inc" "$swift")"
printf '{"type":"x","note":"a\xe2\x80\xa8b"}\n' >>"$inc"
run rules-require-read 0 "rules: 続きの行を足しても通る" "$(edit s5 main "$inc" "$swift")"
out=$(python3 -I - "$root" "$inc" 2>&1 <<'EOF'
import json, os, sys
sys.path.insert(0, sys.argv[1] + "/lib")
from transcripts import tail_lines
lines, end = tail_lines(sys.argv[2], 1_000_000)
print(len(lines), end == os.path.getsize(sys.argv[2]))
EOF
)
match "rules: tail_lines は U+2028 で行を割らず、読み終えた位置を返す" "$out" "1 True"
sleep 1
echo "{\"type\":\"system\",\"subtype\":\"compact_boundary\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" >>"$inc"
sleep 1
run rules-require-read 2 "rules: 前に調べた続きの圧縮の印でも、また止まる" "$(edit s5 main "$inc" "$swift")"
out=$(python3 -I - "$root" "$work/stale" 2>&1 <<'EOF'
import os, sys, time
sys.path.insert(0, sys.argv[1] + "/lib")
from hook_state import prepare_state
folder = sys.argv[2]
os.makedirs(folder + "/old")
for name, age in (("old/new", 0), ("old/dead", 100), ("alone", 100)):
    open(os.path.join(folder, name), "w").close()
    os.utime(os.path.join(folder, name), (time.time() - age, time.time() - age))
os.utime(folder + "/old", (time.time() - 100, time.time() - 100))
prepare_state(folder, 50)
first = sorted(os.listdir(folder + "/old")), os.path.exists(folder + "/alone")
open(folder + "/later", "w").close()
os.utime(folder + "/later", (time.time() - 100, time.time() - 100))
prepare_state(folder, 50)
print(first, os.path.exists(folder + "/later"))
EOF
)
check "rules: 古いフォルダの中の新しい記録を残し、掃除は 1 時間に 1 回にする" test "$out" = "(['new'], False) True"

finish
