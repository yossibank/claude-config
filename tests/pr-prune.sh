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
git -C "$repo" checkout -q -b feat/rebased main
echo r >"$repo/r.md"
commit "$repo" rebased
rebased_head=$(git -C "$repo" -c user.name=t -c user.email=t@t commit-tree "HEAD^{tree}" -p main -m "rebased on github")
git -C "$repo" checkout -q main
git -C "$repo" merge -q --squash feat/rebased >/dev/null && commit "$repo" "squash rebased"
echo r2 >"$repo/r.md"
commit "$repo" "change r after merge"
git -C "$repo" push -q origin main
GH_PR="MERGED $rebased_head feat/rebased" expect OK "prune: 中身がマージした PR の先頭と同じなら、コミットが違っても消す" bash "$prune" "$repo" feat/rebased 5
echo dirty >"$repo/dirty.md"
GH_PR="MERGED x feat/x" expect "未 commit" "prune: 手元に変更があれば止まる" bash "$prune" "$repo" feat/x 3
rm -f "$repo/dirty.md"

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git -C "$repo" checkout -q -b feat/base main
echo b1 >"$repo/b.md"
commit "$repo" base
git -C "$repo" push -q origin feat/base 2>/dev/null
base_head=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q -b feat/child
echo b2 >"$repo/b.md"
commit "$repo" child
git -C "$repo" push -q origin feat/child 2>/dev/null
git -C "$repo" checkout -q -b feat/grand
echo g >"$repo/g.md"
commit "$repo" grand
git -C "$repo" checkout -q main
git -C "$repo" worktree add -q "$work/child-tree" feat/child
git -C "$repo" merge -q --squash feat/base >/dev/null && commit "$repo" "squash base"
git -C "$repo" push -q origin main
out=$(GH_PR="MERGED $base_head feat/base" bash "$prune" "$repo" feat/base 6 2>&1)
match "restack: squash でマージした下のブランチの上の子を、main に載せ直して push する" "$out" "*OK 付け替えた: feat/child（push した）*"
match "restack: 孫も、付け替えた子の上に載せ直す" "$out" "*OK 付け替えた: feat/grand（origin に無いので push していない）*"
check "restack: 子の親が main の先頭になる" test "$(git -C "$repo" rev-parse feat/child^)" == "$(git -C "$repo" rev-parse main)"
check "restack: 孫の親が付け替えた子になる" test "$(git -C "$repo" rev-parse feat/grand^)" == "$(git -C "$repo" rev-parse feat/child)"
check "restack: 子の中身は子の変更のまま" test "$(cat "$work/child-tree/b.md")" == b2
check "restack: origin の子も付け替えた先になる" test "$(git -C "$repo" rev-parse origin/feat/child)" == "$(git -C "$repo" rev-parse feat/child)"
check "restack: 一時のワークツリーを残さない" test -z "$(git -C "$repo" worktree list | grep 'feat/grand')"

git -C "$repo" checkout -q -b feat/ff main
echo f >"$repo/f.md"
commit "$repo" ff
ff_head=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q main
git -C "$repo" merge -q --ff-only feat/ff
git -C "$repo" push -q origin main
git -C "$repo" branch -q feat/after main
after_head=$(git -C "$repo" rev-parse feat/after)
out=$(GH_PR="MERGED $ff_head feat/ff" bash "$prune" "$repo" feat/ff 8 2>&1)
match "restack: squash でないマージでは付け替えない" "$out" "OK repo:*"
check "restack: main から切ったブランチはそのまま" test "$(git -C "$repo" rev-parse feat/after)" == "$after_head"

git -C "$repo" checkout -q -b feat/base2 main
echo x >"$repo/a.md"
commit "$repo" base2
base2_head=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q -b feat/kid
echo y >"$repo/a.md"
commit "$repo" kid
kid_head=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout -q -b feat/dirty-kid feat/base2
echo k >"$repo/k.md"
commit "$repo" dirty-kid
git -C "$repo" checkout -q -b feat/busy-kid feat/base2
echo m >"$repo/m.md"
commit "$repo" busy-kid
git -C "$repo" checkout -q main
git -C "$repo" worktree add -q "$work/dirty-tree" feat/dirty-kid
git -C "$repo" worktree add -q "$work/busy-tree" feat/busy-kid
mkdir -p "$(git -C "$work/busy-tree" rev-parse --path-format=absolute --git-path rebase-merge)"
echo note >"$work/dirty-tree/note.md"
git -C "$repo" merge -q --squash feat/base2 >/dev/null && commit "$repo" "squash base2"
echo z >"$repo/a.md"
commit "$repo" "change a after merge"
git -C "$repo" push -q origin main
GH_PR="MERGED $base2_head feat/base2" expect "NG 付け替えなかった: feat/kid（コンフリクトした）" "restack: コンフリクトしたら NG を出す" bash "$prune" "$repo" feat/base2 7
check "restack: コンフリクトしたブランチは元のまま残す" test "$(git -C "$repo" rev-parse feat/kid)" == "$kid_head"
GH_PR="MERGED $base2_head feat/base2" expect "未 commit の変更がある" "restack: ワークツリーに未 commit の変更があれば付け替えない" bash "$prune" "$repo" feat/base2 7
GH_PR="MERGED $base2_head feat/base2" expect "rebase か merge の途中である" "restack: rebase の途中のワークツリーは付け替えない" bash "$prune" "$repo" feat/base2 7
check "restack: 途中の rebase を中止しない" test -d "$(git -C "$work/busy-tree" rev-parse --path-format=absolute --git-path rebase-merge)"

finish
