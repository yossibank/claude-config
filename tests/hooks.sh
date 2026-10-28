#!/bin/bash
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work/state/"
mkdir -p "$TMPDIR"
guard="$root/hooks/pre-edit-load-rules.py"
bash_edits="$root/hooks/bash-check-edits.py"
shell="$root/hooks/post-edit-check-shell.py"
rules="$root/rules"
fails=0

app="$work/app"
mkdir -p "$app/ios/Features" "$app/docs"
echo 'struct A {}' >"$app/ios/Features/HomeView.swift"
echo '# 概要' >"$app/docs/overview.md"
echo '{}' >"$app/data.json"
git -C "$app" init -q
git -C "$app" add -A
git -C "$app" -c user.name=t -c user.email=t@t commit -q -m init
swift="$app/ios/Features/HomeView.swift"

run() {
    local hook=$1 expect=$2 label=$3 payload=$4 out status
    shift 4
    out=$(echo "$payload" | python3 -I "$hook" "$@" 2>&1)
    status=$?
    if [[ $status == "$expect" ]]; then
        echo "OK ${label}"
    else
        echo "NG ${label}（終了コード ${status}、期待は ${expect}）"
        echo "$out" | head -3
        fails=$((fails + 1))
    fi
}

edit() {
    echo "{\"session_id\":\"$1\",\"agent_id\":\"$2\",\"tool_name\":\"Edit\",\"transcript_path\":\"$3\",\"tool_input\":{\"file_path\":\"$4\"}}"
}

read_rule() {
    echo "{\"session_id\":\"$1\",\"agent_id\":\"$2\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$rules/$3\"}}" | python3 -I "$guard"
}

bash_call() {
    echo "{\"session_id\":\"b\",\"tool_use_id\":\"$1\",\"cwd\":\"$app\",\"tool_input\":{\"command\":\"$2\"}}"
}

log="$work/t.jsonl"
: >"$log"
run "$guard" 2 "rules: 読まずに Swift を編集すると止まる" "$(edit s1 main "$log" "$swift")"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s1 main "$name"; done
run "$guard" 0 "rules: Read した後は通る" "$(edit s1 main "$log" "$swift")"
sleep 1
echo "{\"type\":\"system\",\"subtype\":\"compact_boundary\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" >>"$log"
sleep 1
run "$guard" 2 "rules: 読んだ後に圧縮があれば、また止まる" "$(edit s1 main "$log" "$swift")"
auto="$HOME/.claude/rules"
echo "{\"type\":\"attachment\",\"attachment\":{\"type\":\"instructions\",\"files\":[{\"path\":\"$auto/code-comments.md\"},{\"path\":\"$auto/swift-core.md\"},{\"path\":\"$auto/swift-ui.md\"}]}}" >>"$log"
run "$guard" 0 "rules: 圧縮の後に自動で読み込まれた印があれば通る" "$(edit s1 main "$log" "$swift")"
run "$guard" 0 "rules: 当たる rules が無いファイルは止めない" "$(edit s1 main "$log" "$app/data.json")"
echo '# メモ' >"$work/memo.md"
run "$guard" 0 "rules: git の外のファイル（メモリ・プラン）は止めない" "$(edit s1 main "$log" "$work/memo.md")"
: >"$work/empty.jsonl"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s3 main "$name" & done
wait
run "$guard" 0 "rules: 同時に Read しても取りこぼさない" "$(edit s3 main "$work/empty.jsonl" "$swift")"
fresh="$work/t2.jsonl"
: >"$fresh"
for name in docs-writing.md docs-app.md; do read_rule s2 main "$name"; done
run "$guard" 2 "rules: サブエージェントは親の記録を使わない" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
for name in docs-writing.md docs-app.md; do read_rule s2 a1 "$name"; done
run "$guard" 0 "rules: サブエージェントが自分で読めば通る" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
CLAUDE_RULES_GUARD=off run "$guard" 0 "rules: CLAUDE_RULES_GUARD=off で止めない" "$(edit s9 main "$fresh" "$swift")"
run "$guard" 0 "rules: 壊れた入力では止めない" "not json"

printf '#!/bin/bash\necho "x $name%s"\n' '。' >"$work/wide.sh"
printf '#!/bin/bash\necho "x ${name}。"\n' >"$work/ok.sh"
run "$shell" 2 "shell: 変数の直後の全角で止まる" "{\"tool_input\":{\"file_path\":\"$work/wide.sh\"}}"
run "$shell" 0 "shell: \${名前} で囲めば通る" "{\"tool_input\":{\"file_path\":\"$work/ok.sh\"}}"

run "$bash_edits" 0 "bash: 書き換える前の状態を残す" "$(bash_call t1 'sed -i')" pre
sed -i '' 's/概要/概要です/' "$app/docs/overview.md"
run "$bash_edits" 2 "bash: Bash で .md を書き換えると知らせて検査する" "$(bash_call t1 'sed -i')" post
run "$bash_edits" 0 "bash: 前の状態を残す" "$(bash_call t2 'git checkout')" pre
git -C "$app" checkout -q -- docs/overview.md
run "$bash_edits" 0 "bash: git での変更は知らせない" "$(bash_call t2 'git checkout')" post
run "$bash_edits" 0 "bash: 前の状態を残す" "$(bash_call t3 'ls')" pre
run "$bash_edits" 0 "bash: 何も変えなければ知らせない" "$(bash_call t3 'ls')" post
run "$bash_edits" 0 "bash: 前の状態を残す" "$(bash_call t4 'cd app && git checkout')" pre
echo 'x' >>"$app/docs/overview.md"
run "$bash_edits" 0 "bash: cd と git だけのコマンドは知らせない" "$(bash_call t4 'cd app && git checkout')" post
run "$bash_edits" 0 "bash: 前の状態を残す" "$(bash_call t5 'sed -i x && git add')" pre
echo 'y' >>"$app/docs/overview.md"
run "$bash_edits" 2 "bash: git が混ざっても書き換えは知らせる" "$(bash_call t5 'sed -i x && git add')" post

exit "$fails"
