#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

run rules-detect-bash-edits 1 "bash: 知らないモードは止めずに知らせる" "$(bash_call t0 'ls')" before
run rules-detect-bash-edits 0 "bash: 書き換える前の状態を残す" "$(bash_call t1 'sed -i')" pre
sed -i '' 's/概要/概要です/' "$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: Bash で .md を書き換えると知らせて検査する" "$(bash_call t1 'sed -i')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t2 'git checkout')" pre
git -C "$app" checkout -q -- docs/overview.md
run rules-detect-bash-edits 0 "bash: git での変更は知らせない" "$(bash_call t2 'git checkout')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t3 'ls')" pre
run rules-detect-bash-edits 0 "bash: 何も変えなければ知らせない" "$(bash_call t3 'ls')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t4 'cd app && git checkout')" pre
echo 'x' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: cd と git だけのコマンドは知らせない" "$(bash_call t4 'cd app && git checkout')" post
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

finish
