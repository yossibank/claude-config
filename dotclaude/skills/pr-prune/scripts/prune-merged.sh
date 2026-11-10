#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../../lib/git.sh"

fail() {
    echo "NG $name: $1"
    exit 1
}

clean_derived_data() {
    local plist path volume
    local count=0

    for plist in "$HOME"/Library/Developer/Xcode/DerivedData/*/info.plist; do
        path=$(plutil -extract WorkspacePath raw "$plist" 2>/dev/null) || continue

        case $path in
            "$repo"/* | "$(worktree_root "$name")"/*) ;;
            *) continue ;;
        esac

        # 外付けのボリュームが外れている間は、フォルダが見えないだけで、消えたとは限らない
        case $path in
            /Volumes/*)
                volume=${path#/Volumes/}
                [[ -d /Volumes/${volume%%/*} ]] || continue
                ;;
        esac

        if [[ ! -e $path ]]; then
            rm -rf "$(dirname "$plist")"
            count=$((count + 1))
        fi
    done

    echo "$count"
}

merged() {
    local branch=$1 head=$2 main=$3
    local tip base
    tip=$(git -C "$repo" rev-parse "refs/heads/$branch")
    [[ $tip == "$head" ]] && return 0
    git -C "$repo" merge-base --is-ancestor "$tip" "origin/$main" && return 0
    [[ -n $head ]] && git -C "$repo" merge-base --is-ancestor "$tip" "$head" 2>/dev/null && return 0
    [[ -n $head ]] && git -C "$repo" diff --quiet "$head" "$tip" 2>/dev/null && return 0
    git -C "$repo" diff --quiet "origin/$main" "$branch" && return 0
    base=$(git -C "$repo" merge-base "origin/$main" "$branch")
    git -C "$repo" diff --binary "$base" "$branch" | git -C "$repo" apply -R --check 2>/dev/null
}

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <ブランチ名> <PR 番号>"; exit 1; }

use_repo "$1"
branch=$2
pr=$3
name=$(basename "$repo")

info=$(cd "$repo" && gh pr view "$pr" --json state,headRefOid,headRefName,baseRefName \
    -q '"\(.state) \(.headRefOid) \(.headRefName) \(.baseRefName)"') || fail "PR #$pr を gh pr view で読めない"
read -r state head ref base_ref <<< "$info"
[[ $state == MERGED ]] || fail "PR #$pr が MERGED ではない（${state}）"
[[ $ref == "$branch" ]] || head=""
if [[ -n $head ]] && ! git -C "$repo" cat-file -e "$head^{commit}" 2>/dev/null; then
    git -C "$repo" fetch -q origin "pull/$pr/head" 2>/dev/null || true
fi

main=$(default_branch "$repo")
main=${main#origin/}
[[ $(git -C "$repo" branch --show-current) == "$main" ]] || fail "手元が $main ではない"
[[ -z $(git -C "$repo" status --porcelain) ]] || fail "手元に未 commit の変更がある"
errors=$(git -C "$repo" pull -q --ff-only origin "$main" 2>&1) || fail "pull --ff-only が通らない（$(tail -n 1 <<< "$errors")）"
[[ $(git -C "$repo" rev-parse HEAD) == $(git -C "$repo" rev-parse "origin/$main") ]] \
    || fail "手元の $main に、origin に無い commit がある"

tip=$head
if git -C "$repo" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    merged "$branch" "$head" "$main" || fail "$branch の中身が $main に入っていない。ワークツリーとブランチは残した"
    tip=$(git -C "$repo" rev-parse "refs/heads/$branch")
    if [[ -n $head ]] && git -C "$repo" merge-base --is-ancestor "$tip" "$head" 2>/dev/null; then
        tip=$head
    fi
    worktree=$(worktree_of "$repo" "$branch")
    [[ -z $worktree ]] || git -C "$repo" worktree remove "$worktree" 2>/dev/null \
        || fail "ワークツリーを消せない。未 commit や未追跡のファイルを確かめる: $worktree"
    git -C "$repo" branch -q -D "$branch" || fail "ブランチを消せない: $branch"
fi

errors=$(git -C "$repo" fetch -q --prune origin 2>&1) || fail "fetch --prune が通らない（$(tail -n 1 <<< "$errors")）"
remote=$(git -C "$repo" ls-remote origin "refs/heads/$branch") && { [[ -z $remote ]] && left="なし" || left="残っている"; } || left="確かめられなかった"
derived=$(clean_derived_data)
echo "OK $name: $(git -C "$repo" rev-parse --short HEAD) | 手元の $main は origin と一致 | GitHub 上のブランチ: $left | 消した DerivedData: $derived"
base_ref=${base_ref:-$main}
if [[ -n $tip ]] && git -C "$repo" cat-file -e "$tip^{commit}" 2>/dev/null \
    && git -C "$repo" rev-parse -q --verify "origin/$base_ref" >/dev/null \
    && ! git -C "$repo" merge-base --is-ancestor "$tip" "origin/$base_ref"; then
    "$(dirname "$0")/replace-base.sh" "$repo" "$tip" "$base_ref" "$main" || exit 1
fi
