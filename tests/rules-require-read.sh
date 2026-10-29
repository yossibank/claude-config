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
run rules-require-read 0 "rules: 当たる rules が無いファイルは止めない" "$(edit s1 main "$log" "$app/data.json")"
echo '# メモ' >"$work/memo.md"
run rules-require-read 0 "rules: git の外のファイル（メモリ・プラン）は止めない" "$(edit s1 main "$log" "$work/memo.md")"
: >"$work/empty.jsonl"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s3 main "$name" & done
wait
run rules-require-read 0 "rules: 同時に Read しても取りこぼさない" "$(edit s3 main "$work/empty.jsonl" "$swift")"
fresh="$work/t2.jsonl"
: >"$fresh"
for name in docs-writing.md docs-app.md docs-human.md; do read_rule s2 main "$name"; done
run rules-require-read 2 "rules: サブエージェントは親の記録を使わない" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
for name in docs-writing.md docs-app.md docs-human.md; do read_rule s2 a1 "$name"; done
run rules-require-read 0 "rules: サブエージェントが自分で読めば通る" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
CLAUDE_HOOKS_OFF="pr-gate rules-require-read" run rules-require-read 0 "rules: CLAUDE_HOOKS_OFF に名前があれば止めない" "$(edit s9 main "$fresh" "$swift")"
run rules-require-read 0 "rules: 壊れた入力では止めない" "not json"
odd="$work/odd.jsonl"
printf '%s\n' '{"type":"x","note":"instructions","attachment":"/rules/"}' '{"type":"attachment","attachment":{"type":"instructions","files":["/rules/x.md"]}}' >"$odd"
run rules-require-read 2 "rules: 記録の attachment が辞書でなくても落ちずに止める" "$(edit s8 main "$odd" "$swift")"

finish
