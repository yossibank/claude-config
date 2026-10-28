#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

export HOME="$work/home"
mkdir -p "$HOME"
prune="$root/skills/pr-prune/scripts/prune-merged.sh"
fake_gh 'echo "${GH_PR:-MERGED x x}"'
repo="$work/repo"
clone_with_origin "$repo"

git -C "$repo" checkout -q -b feat/done
echo d >"$repo/d.md"
commit "$repo" done
git -C "$repo" push -q origin feat/done 2>/dev/null
done_head=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q main
git -C "$repo" merge -q --squash feat/done >/dev/null && commit "$repo" "squash"
git -C "$repo" push -q origin main
git -C "$repo" push -q origin --delete feat/done 2>/dev/null

git -C "$repo" checkout -q -b feat/open
echo e >"$repo/e.md"
commit "$repo" open
git -C "$repo" checkout -q main
git -C "$repo" worktree add -q "$work/open-tree" feat/open

expect "使い方" "prune: 引数が足りなければ NG" bash "$prune" "$repo" feat/done
GH_PR="OPEN $done_head feat/done" expect "MERGED ではない" "prune: マージ前は止まる" bash "$prune" "$repo" feat/done 1
GH_PR="MERGED $done_head feat/done" expect OK "prune: squash でマージしたブランチを消す" bash "$prune" "$repo" feat/done 1
if git -C "$repo" rev-parse -q --verify refs/heads/feat/done >/dev/null; then
    ng "prune: ブランチが消えた"
else
    ok "prune: ブランチが消えた"
fi
GH_PR="MERGED x feat/open" expect "入っていない" "prune: 中身が入っていないブランチは残す" bash "$prune" "$repo" feat/open 2
check "prune: 入っていないブランチのワークツリーは残す" test -d "$work/open-tree"
git -C "$repo" worktree add -q -b feat/kept "$work/kept-tree" main
echo note >"$work/kept-tree/note.md"
GH_PR="MERGED x feat/kept" expect "ワークツリーを消せない" "prune: 未追跡のファイルがあるワークツリーは消さずに止まる" bash "$prune" "$repo" feat/kept 4
check "prune: 未追跡のファイルは残る" test -f "$work/kept-tree/note.md"
echo dirty >"$repo/dirty.md"
GH_PR="MERGED x feat/x" expect "未 commit" "prune: 手元に変更があれば止まる" bash "$prune" "$repo" feat/x 3
rm -f "$repo/dirty.md"

finish
