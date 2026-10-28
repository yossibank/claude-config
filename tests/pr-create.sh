#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

export HOME="$work/home"
mkdir -p "$HOME"
scripts="$root/skills/pr-create/scripts"
repo="$work/repo"
clone_with_origin "$repo"

expect "NG 使い方" "classify: 引数が足りなければ NG" bash "$scripts/classify-diff.sh" "$repo"
expect "差分が無い" "classify: 差分が無ければ NG" bash "$scripts/classify-diff.sh" "$repo" origin/main
echo b >"$repo/日本語.md"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
if [[ $out == "docs | 1 行"* ]]; then
    ok "classify: 日本語の名前の文書だけなら docs"
else
    ng "classify: 日本語の名前の文書だけなら docs" "$out"
fi
echo 'x' >"$repo/hooks.py"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
if [[ $out == small* ]]; then
    ok "classify: コードが混ざれば small"
else
    ng "classify: コードが混ざれば small" "$out"
fi
rm -f "$repo/hooks.py" "$repo/日本語.md"

expect "確認が無い" "body: 確認が無ければ本文を作らない" bash "$scripts/write-body.sh" "$repo" origin/main
bash "$scripts/run-check.sh" "$repo" true true >/dev/null
expect OK "body: 確認が通れば本文を作る" bash "$scripts/write-body.sh" "$repo" origin/main "画面"
check "body: 未検証の項目を付ける" grep -q -- '- \[ \] 画面（未検証）' "$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-body.txt)"
echo c >>"$repo/a.md"
expect "確認の後に変更がある" "body: 確認の後に変えたら止まる" bash "$scripts/write-body.sh" "$repo" origin/main
git -C "$repo" checkout -q -- a.md

route="$scripts/route-pr.sh"
echo body >"$work/body.txt"
fake_gh 'echo "o n ${GH_PERMISSION:-WRITE}"'
expect "NG 使い方" "route: 引数が足りなければ NG" bash "$route" "$repo" main title
out=$(bash "$route" "$repo" main title "$work/body.txt")
check "route: 書き込める時は gh で作る" test "$out" == gh
out=$(GH_PERMISSION=READ bash "$route" "$repo" main title "$work/body.txt")
check "route: 読むだけの時は compare の URL を出す" test "$out" == "compare https://github.com/o/n/compare/main...main?expand=1&title=title&body=body%0A"

create="$scripts/create-worktree.sh"
expect "NG 使い方" "create-worktree: 引数が足りなければ NG" bash "$create" "$repo"
expect "形ではない" "create-worktree: 形の違うブランチ名は NG" bash "$create" "$repo" Feature/X
expect OK "create-worktree: ワークツリーを作る" bash "$create" "$repo" feat/new-thing
check "create-worktree: ~/.claude/worktrees の下に置く" test -d "$HOME/.claude/worktrees/repo/feat-new-thing"
check "create-worktree: origin の既定のブランチから切る" test "$(git -C "$HOME/.claude/worktrees/repo/feat-new-thing" rev-parse HEAD)" == "$(git -C "$repo" rev-parse origin/main)"

finish
