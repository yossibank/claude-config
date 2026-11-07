#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hook_fixtures.sh"
STOP="Bash でファイルを書き換えた"

run rules-detect-bash-edits 1 "bash: 知らないモードは止めずに知らせる" "$(bash_call t0 'ls')" before
run rules-detect-bash-edits 0 "bash: 書き換える前の状態を残す" "$(bash_call t1 'sed -i')" pre
printf '# 概要です\n' >"$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: Bash で .md を書き換えると知らせて検査する" "$(bash_call t1 'sed -i')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t2 'git checkout')" pre
git -C "$app" checkout -q -- docs/overview.md
run rules-detect-bash-edits 0 "bash: git での変更は知らせない" "$(bash_call t2 'git checkout')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t2b 'git checkout other -- docs/overview.md')" pre
echo 'q' >>"$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: git checkout で .md が変わったら検査する" "$(bash_call t2b 'git checkout other -- docs/overview.md')" post
git -C "$app" checkout -q -- docs/overview.md
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t2c 'git status')" pre
echo 'q' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: git status では検査しない" "$(bash_call t2c 'git status')" post
git -C "$app" checkout -q -- docs/overview.md
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t3 'ls')" pre
run rules-detect-bash-edits 0 "bash: 何も変えなければ知らせない" "$(bash_call t3 'ls')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t4 'cd app && git status')" pre
echo 'x' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: cd と git だけのコマンドは知らせない" "$(bash_call t4 'cd app && git status')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t5 'sed -i x && git add')" pre
echo 'y' >>"$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: git が混ざっても書き換えは知らせる" "$(bash_call t5 'sed -i x && git add')" post
echo '# 日本語' >"$app/docs/日本語.md"
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t6 'sed -i')" pre
echo 'z' >>"$app/docs/日本語.md"
run rules-detect-bash-edits 2 "bash: 日本語の名前のファイルの書き換えも知らせる" "$(bash_call t6 'sed -i')" post
rm -f "$app/docs/日本語.md"
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t8 'git commit -m \"a; sed -i\"')" pre
echo 'w' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: 引用符の中の ; に引きずられず、git だけと数える" "$(bash_call t8 'git commit -m \"a; sed -i\"')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t7 'sed -i')" pre
printf '# t\n\n```\nx\n```\n' >"$app/docs/off.md"
out=$(bash_call t7 'sed -i' | CC_HOOKS_OFF="docs-check,rules-require-read" bash "$hooks" rules-detect-bash-edits post 2>&1)
if [[ $out == *off.md* && $out != *言語を付ける* && $out != *当たる決まり* ]]; then
    ok "bash: CC_HOOKS_OFF で止めた検査は、Bash の書き換えにもかけない"
else
    ng "bash: CC_HOOKS_OFF で止めた検査は、Bash の書き換えにもかけない" "$out"
fi
rm -f "$app/docs/off.md"
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t9 'sed -i')" pre
echo 'v' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: Edit の印を残す" "$(edit s a "" "$app/docs/overview.md")" edit
run rules-detect-bash-edits 0 "bash: Bash の間に Edit で変えたファイルは数えない" "$(bash_call t9 'sed -i')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t10 'sed -i')" pre
echo 'u' >>"$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: Bash の前の Edit の印では、Bash の書き換えを見逃さない" "$(bash_call t10 'sed -i')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t11 'gh pr view 1 > docs/overview.md')" pre
echo 't' >>"$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: git・gh でも、出力をファイルに書けば知らせる" "$(bash_call t11 'gh pr view 1 > docs/overview.md')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t12 'git status 2>/dev/null >&2')" pre
echo 's' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: /dev/null と fd への向け替えは書き込みと数えない" "$(bash_call t12 'git status 2>/dev/null >&2')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t13 "git status > $work/redirect.log")" pre
echo 'r' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: 道具の出力を別の所に向けても、道具が変えたファイルは数えない" "$(bash_call t13 "git status > $work/redirect.log")" post
echo "{}" >"$app/docs/quiet.json"
for tool in make mint swiftformat pre-commit brew xcodebuild swift; do
    run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call "tool-$tool" "$tool run")" pre
    echo "$tool" >>"$app/docs/quiet.json"
    run rules-detect-bash-edits 0 "bash: $tool の書き換えで検査が通れば黙る" "$(bash_call "tool-$tool" "$tool run")" post
done
rm -f "$app/docs/quiet.json"
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t20 'make fmt')" pre
printf '# t\n\n```\nx\n```\n' >"$app/docs/tool.md"
out=$(bash_call t20 'make fmt' | bash "$hooks" rules-detect-bash-edits post 2>&1)
rc=$?
if [[ $rc == 2 && $out == *tool.md* && $out != *Edit・Write* ]]; then
    ok "bash: make の書き換えで検査が NG なら、NG の行だけ返す"
else
    ng "bash: make の書き換えで検査が NG なら、NG の行だけ返す" "$rc $out"
fi
rm -f "$app/docs/tool.md"

run rules-detect-bash-edits 0 "bash: 読むだけのコマンドは、前の状態を残さない" "$(bash_call t13 'ls docs | head -3')" pre
check "bash: 読むだけのコマンドは git status を走らせず、状態のファイルを作らない" test ! -e "$TMPDIR/claude-bash-edits/b-t13"
no_id() {
    echo "{\"session_id\":\"n\",\"cwd\":\"$app\",\"tool_input\":{\"command\":\"$1\"}}"
}
run rules-detect-bash-edits 0 "bash: tool_use_id が無くても前の状態を残す" "$(no_id 'sed -i a')" pre
run rules-detect-bash-edits 0 "bash: tool_use_id が無くても別のコマンドは別の状態にする" "$(no_id 'sed -i b')" pre
check "bash: tool_use_id が無い時は、コマンドごとに状態のファイルを分ける" test "$(find "$TMPDIR/claude-bash-edits" -name 'n-*' | wc -l | tr -d ' ')" = 2

finish
