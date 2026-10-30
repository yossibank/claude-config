#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$root/lib/git.sh"

export HOME="$work/home"
mkdir -p "$HOME"
scripts="$root/skills/pr-create/scripts"
repo="$work/repo"
clone_with_origin "$repo"

expect "NG 使い方" "classify-diff: 引数が足りなければ NG" bash "$scripts/classify-diff.sh" "$repo"
expect "差分が無い" "classify-diff: 差分が無ければ NG" bash "$scripts/classify-diff.sh" "$repo" origin/main
echo b >"$repo/日本語.md"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
if [[ $out == "docs | 1 行"* ]]; then
    ok "classify-diff: 日本語の名前の文書だけなら docs"
else
    ng "classify-diff: 日本語の名前の文書だけなら docs" "$out"
fi
echo 'x' >"$repo/hooks.py"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
if [[ $out == small* ]]; then
    ok "classify-diff: コードが混ざれば small"
else
    ng "classify-diff: コードが混ざれば small" "$out"
fi
rm -f "$repo/hooks.py" "$repo/日本語.md"
printf '\0\1' >"$repo/a.bin"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
match "classify-diff: 行の無いファイルだけの差分も、差分が無いとしない" "$out" "small | 0 行*"
rm -f "$repo/a.bin"
expect "NG nope との分かれ目が見つからない" "classify-diff: base が無ければ NG" bash "$scripts/classify-diff.sh" "$repo" nope
expect "NG nope との分かれ目が見つからない" "write-body: base が無ければ NG" bash "$scripts/write-body.sh" "$repo" nope

expect "確認が無い" "write-body: 確認が無ければ本文を作らない" bash "$scripts/write-body.sh" "$repo" origin/main
echo b >"$repo/a|b.md"
echo b >"$repo/日本語.md"
bash "$scripts/run-check.sh" "$repo" true true >/dev/null
expect OK "write-body: 確認が通れば本文を作る" bash "$scripts/write-body.sh" "$repo" origin/main "画面"
pr_body=$(git_file "$repo" pr-body.txt)
check "write-body: 通った確認に ✅ を付ける" grep -qF '| true | ✅ 通った |' "$pr_body"
check "write-body: 差分の重さを、色と行数とレビューで出す" grep -qF '| 差分の重さ | ⚪ docs・2 行。レビュー: 自分で見る |' "$pr_body"
check "write-body: 未検証の項目に ⬜ を付ける" grep -qF '| 画面 | ⬜ 未検証 |' "$pr_body"
check "write-body: 変えたファイルを表の行にし、| を逃がす" grep -qF '| `a\|b.md` | |' "$pr_body"
check "write-body: 日本語の名前のファイルを、引用符と 8 進の表記にせずに出す" grep -qF '| `日本語.md` | |' "$pr_body"
echo c >>"$repo/a.md"
expect "確認の後に変更がある" "write-body: 確認の後に変えたら止まる" bash "$scripts/write-body.sh" "$repo" origin/main
git -C "$repo" checkout -q -- a.md
rm -f "$repo/a|b.md" "$repo/日本語.md"
bash "$scripts/run-check.sh" "$repo" true true >/dev/null
expect OK "write-body: 差分が無くても本文を作る" bash "$scripts/write-body.sh" "$repo" origin/main
check "write-body: 差分が無ければ重さの行を出さない" bash -c '! grep -q "差分の重さ" "$1"' _ "$pr_body"
echo 'x' >"$repo/a.swift"
bash "$scripts/run-check.sh" "$repo" true true >/dev/null
bash "$scripts/write-body.sh" "$repo" origin/main >/dev/null
check "write-body: コードの差分は 🟡 small" grep -qF '| 差分の重さ | 🟡 small・1 行。' "$pr_body"
mkdir -p "$repo/hooks"
mv "$repo/a.swift" "$repo/hooks/a.py"
bash "$scripts/run-check.sh" "$repo" true true >/dev/null
bash "$scripts/write-body.sh" "$repo" origin/main >/dev/null
check "write-body: 触れた所が出る差分も、🔴 large の行を出す" grep -qF '| 差分の重さ | 🔴 large・1 行。' "$pr_body"
rm -rf "$repo/hooks"

lock="$(git_file "$repo" pr-checks).lock"
mkdir "$lock"
touch -t 202001010000 "$lock"
expect OK "run-check: 古いロックは外して進む" bash "$scripts/run-check.sh" "$repo" stale true
check "run-check: 終わったらロックを残さない" test ! -d "$lock"
expect "確認の間にワークツリーが変わった" "run-check: 確認の間にワークツリーが変われば NG" bash "$scripts/run-check.sh" "$repo" touchy sh -c 'echo x >changed.txt'
check "run-check: 確認の間に変わった記録を NG で残す" grep -q "^NG	touchy	" "$(git_file "$repo" pr-checks)"
rm -f "$repo/changed.txt"
bash "$scripts/run-check.sh" "$repo" --drop touchy >/dev/null

route="$scripts/route-pr.sh"
echo body >"$work/body.txt"
fake_gh 'echo "o n ${GH_PERMISSION:-WRITE}"'
expect "NG 使い方" "route-pr: 引数が足りなければ NG" bash "$route" "$repo" main title
out=$(bash "$route" "$repo" main title "$work/body.txt")
check "route-pr: 書き込める時は gh で作る" test "$out" == gh
out=$(GH_PERMISSION=READ bash "$route" "$repo" main title "$work/body.txt")
check "route-pr: 読むだけの時は compare の URL を出す" test "$out" == "compare https://github.com/o/n/compare/main...main?expand=1&title=title&body=body%0A"

create="$scripts/create-worktree.sh"
expect "NG 使い方" "create-worktree: 引数が足りなければ NG" bash "$create" "$repo"
expect "形ではない" "create-worktree: 形の違うブランチ名は NG" bash "$create" "$repo" Feature/X
expect OK "create-worktree: ワークツリーを作る" bash "$create" "$repo" feat/new-thing
check "create-worktree: ~/.claude/worktrees の下に置く" test -d "$HOME/.claude/worktrees/repo/feat-new-thing"
check "create-worktree: origin の既定のブランチから切る" test "$(git -C "$HOME/.claude/worktrees/repo/feat-new-thing" rev-parse HEAD)" == "$(git -C "$repo" rev-parse origin/main)"
git init -q --bare -b develop "$work/develop.git"
git -C "$repo" push -q "$work/develop.git" HEAD:refs/heads/develop
git init -q "$work/develop"
git -C "$work/develop" remote add origin "$work/develop.git"
git -C "$work/develop" fetch -q origin
expect OK "create-worktree: origin/HEAD が無くても、origin の既定のブランチを読んで切る" bash "$create" "$work/develop" feat/from-develop
check "create-worktree: 既定のブランチが develop なら develop から切る" test "$(git -C "$HOME/.claude/worktrees/develop/feat-from-develop" rev-parse HEAD)" == "$(git -C "$work/develop" rev-parse origin/develop)"

finish
