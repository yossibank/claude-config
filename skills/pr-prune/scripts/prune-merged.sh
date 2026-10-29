#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <ブランチ名> <PR 番号>"; exit 1; }

use_repo "$1"
branch=$2
pr=$3
name=$(basename "$repo")

fail() {
    echo "NG $name: $1"
    exit 1
}

clean_derived_data() {
    local plist path
    local count=0

    for plist in "$HOME"/Library/Developer/Xcode/DerivedData/*/info.plist; do
        path=$(plutil -extract WorkspacePath raw "$plist" 2>/dev/null) || continue

        case $path in
            "$repo"/* | "$HOME/.claude/worktrees/$name"/*) ;;
            *) continue ;;
        esac

        if [[ ! -e $path ]]; then
            rm -rf "$(dirname "$plist")"
            count=$((count + 1))
        fi
    done

    echo "$count"
}

info=$(cd "$repo" && gh pr view "$pr" --json state,headRefOid,headRefName \
    -q '"\(.state) \(.headRefOid) \(.headRefName)"') || fail "PR #$pr を gh pr view で読めない"
read -r state head ref <<< "$info"
[[ $state == MERGED ]] || fail "PR #$pr が MERGED ではない（${state}）"
[[ $ref == "$branch" ]] || head=""
if [[ -n $head ]] && ! git -C "$repo" cat-file -e "$head^{commit}" 2>/dev/null; then
    git -C "$repo" fetch -q origin "pull/$pr/head" 2>/dev/null || true
fi

merged() {
    local tip base
    tip=$(git -C "$repo" rev-parse "refs/heads/$branch")
    [[ $tip == "$head" ]] && return 0
    git -C "$repo" merge-base --is-ancestor "$tip" "origin/$main" && return 0
    [[ -n $head ]] && git -C "$repo" merge-base --is-ancestor "$tip" "$head" 2>/dev/null && return 0
    git -C "$repo" diff --quiet "origin/$main" "$branch" && return 0
    base=$(git -C "$repo" merge-base "origin/$main" "$branch")
    git -C "$repo" diff "$base" "$branch" | git -C "$repo" apply -R --check 2>/dev/null
}

main=$(default_branch "$repo")
main=${main#origin/}
[[ $(git -C "$repo" branch --show-current) == "$main" ]] || fail "手元が $main ではない"
[[ -z $(git -C "$repo" status --porcelain) ]] || fail "手元に未 commit の変更がある"
git -C "$repo" pull -q --ff-only origin "$main" || fail "pull --ff-only が通らない"
[[ $(git -C "$repo" rev-parse HEAD) == $(git -C "$repo" rev-parse "origin/$main") ]] \
    || fail "手元の $main に、origin に無い commit がある"

if git -C "$repo" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    merged || fail "$branch の中身が $main に入っていない。ワークツリーとブランチは残した"
    worktree=$(git -C "$repo" worktree list --porcelain \
        | awk -v want="branch refs/heads/$branch" '/^worktree /{path=substr($0, 10)} $0 == want {print path}')
    [[ -z $worktree ]] || git -C "$repo" worktree remove "$worktree" 2>/dev/null \
        || fail "ワークツリーを消せない。未 commit や未追跡のファイルを確かめる: $worktree"
    git -C "$repo" branch -q -D "$branch"
fi

git -C "$repo" fetch -q --prune origin
remote=$(git -C "$repo" ls-remote --heads origin "$branch" | wc -l | tr -d ' ')
[[ $remote == 0 ]] && left="なし" || left="残っている"
derived=$(clean_derived_data)
echo "OK $name: $(git -C "$repo" rev-parse --short HEAD) | 手元の $main は origin と一致 | GitHub 上のブランチ: $left | 消した DerivedData: $derived"
