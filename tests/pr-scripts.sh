#!/bin/bash
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
mkdir -p "$HOME" "$work/bin"
scripts="$root/skills/pr-create/scripts"
prune="$root/skills/pr-prune/scripts/prune.sh"
fails=0

cat >"$work/bin/gh" <<'GH'
#!/bin/bash
echo "${GH_PR:-MERGED x x}"
GH
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"

expect() {
    local want=$1 label=$2 out status
    shift 2
    out=$("$@" 2>&1)
    status=$?
    if [[ $want == OK && $status == 0 ]] || [[ $want != OK && $status != 0 && $out == *"$want"* ]]; then
        echo "OK ${label}"
    else
        echo "NG ${label}（終了コード ${status}、期待は ${want}）"
        echo "$out" | head -3
        fails=$((fails + 1))
    fi
}

commit() {
    git -C "$1" add -A
    git -C "$1" -c user.name=t -c user.email=t@t commit -q -m "$2"
}

git init -q --bare -b main "$work/origin.git"
git clone -q "$work/origin.git" "$work/repo" 2>/dev/null
repo="$work/repo"
echo a >"$repo/a.md"
commit "$repo" init
git -C "$repo" push -q origin main
git -C "$repo" remote set-head origin main

expect "NG 使い方" "classify: 引数が足りなければ NG" bash "$scripts/classify.sh" "$repo"
expect "差分が無い" "classify: 差分が無ければ NG" bash "$scripts/classify.sh" "$repo" origin/main
echo b >"$repo/日本語.md"
out=$(bash "$scripts/classify.sh" "$repo" origin/main)
if [[ $out == "docs | 1 行"* ]]; then echo "OK classify: 日本語の名前の文書だけなら docs"; else echo "NG classify: 日本語の名前の文書だけなら docs: $out"; fails=$((fails + 1)); fi
echo 'x' >"$repo/hooks.py"
out=$(bash "$scripts/classify.sh" "$repo" origin/main)
if [[ $out == small* ]]; then echo "OK classify: コードが混ざれば small"; else echo "NG classify: コードが混ざれば small: $out"; fails=$((fails + 1)); fi
rm -f "$repo/hooks.py" "$repo/日本語.md"

expect "確認が無い" "body: 確認が無ければ本文を作らない" bash "$scripts/body.sh" "$repo" origin/main
bash "$scripts/check.sh" "$repo" true true >/dev/null
expect OK "body: 確認が通れば本文を作る" bash "$scripts/body.sh" "$repo" origin/main "画面"
grep -q -- '- \[ \] 画面（未検証）' "$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-body.txt)" \
    && echo "OK body: 未検証の項目を付ける" || { echo "NG body: 未検証の項目を付ける"; fails=$((fails + 1)); }
echo c >>"$repo/a.md"
expect "確認の後に変更がある" "body: 確認の後に変えたら止まる" bash "$scripts/body.sh" "$repo" origin/main
git -C "$repo" checkout -q -- a.md

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
git -C "$repo" rev-parse -q --verify refs/heads/feat/done >/dev/null \
    && { echo "NG prune: ブランチが残った"; fails=$((fails + 1)); } || echo "OK prune: ブランチが消えた"
GH_PR="MERGED x feat/open" expect "入っていない" "prune: 中身が入っていないブランチは残す" bash "$prune" "$repo" feat/open 2
[[ -d $work/open-tree ]] && echo "OK prune: 入っていないブランチのワークツリーは残す" || { echo "NG prune: ワークツリーが消えた"; fails=$((fails + 1)); }
git -C "$repo" worktree add -q -b feat/kept "$work/kept-tree" main
echo note >"$work/kept-tree/note.md"
GH_PR="MERGED x feat/kept" expect "ワークツリーを消せない" "prune: 未追跡のファイルがあるワークツリーは消さずに止まる" bash "$prune" "$repo" feat/kept 4
[[ -f $work/kept-tree/note.md ]] && echo "OK prune: 未追跡のファイルは残る" || { echo "NG prune: 未追跡のファイルが消えた"; fails=$((fails + 1)); }
echo dirty >"$repo/dirty.md"
GH_PR="MERGED x feat/x" expect "未 commit" "prune: 手元に変更があれば止まる" bash "$prune" "$repo" feat/x 3
rm -f "$repo/dirty.md"

exit "$fails"
