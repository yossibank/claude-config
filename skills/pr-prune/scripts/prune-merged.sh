#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

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
            "$repo"/* | "$(worktree_root "$name")"/*) ;;
            *) continue ;;
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
    git -C "$repo" diff "$base" "$branch" | git -C "$repo" apply -R --check 2>/dev/null
}

worktree_of() {
    git -C "$repo" worktree list --porcelain \
        | awk -v want="branch refs/heads/$1" '/^worktree /{path=substr($0, 10)} $0 == want {print path}'
}

stacked_on() {
    local tip=$1 child

    git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads | while IFS= read -r child; do
        [[ $child != "$main" ]] || continue
        git -C "$repo" merge-base --is-ancestor "$tip" "refs/heads/$child" || continue
        [[ $(git -C "$repo" rev-parse "refs/heads/$child") != "$tip" ]] || continue
        printf '%s\t%s\n' "$(git -C "$repo" rev-list --count "$tip..refs/heads/$child")" "$child"
    done | sort -n | cut -f2-
}

remove_temp_tree() {
    [[ -z $temp_tree ]] || git -C "$repo" worktree remove --force "$temp_tree" 2>/dev/null || true
    temp_tree=""
}

in_progress() {
    local state
    for state in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD; do
        [[ ! -e $(git -C "$1" rev-parse --path-format=absolute --git-path "$state") ]] || return 0
    done
    return 1
}

rebase_onto() {
    local child=$1 old_base=$2 new_base=$3
    local worktree status=0

    worktree=$(worktree_of "$child")
    if [[ -z $worktree ]]; then
        temp_tree=$(mktemp -d)
        git -C "$repo" worktree add -q "$temp_tree" "$child" 2>/dev/null || { reason="一時のワークツリーを作れない"; remove_temp_tree; return 1; }
        worktree=$temp_tree
    fi
    if in_progress "$worktree"; then
        reason="rebase か merge の途中である: $worktree"
        status=1
    elif [[ -n $(git -C "$worktree" status --porcelain) ]]; then
        reason="未 commit の変更がある: $worktree"
        status=1
    elif ! git -c rebase.updateRefs=false -C "$worktree" rebase -q --onto "$new_base" "$old_base" >/dev/null 2>&1; then
        git -C "$worktree" rebase --abort 2>/dev/null || true
        reason="コンフリクトした"
        status=1
    fi
    remove_temp_tree
    return "$status"
}

push_restacked() {
    local child=$1 remote_tip

    remote_tip=$(git -C "$repo" ls-remote origin "refs/heads/$child" | cut -f1) || return 1
    [[ -n $remote_tip ]] || { echo "origin に無いので push していない"; return 0; }
    git -C "$repo" push -q --force-with-lease="refs/heads/$child:$remote_tip" origin "refs/heads/$child" 2>/dev/null || return 1
    echo "push した"
}

restack() {
    local tip=$1
    local olds=("$tip") news=("$(git -C "$repo" rev-parse "origin/$main")")
    local child old best best_count count i pushed failed=0

    while IFS= read -r child; do
        [[ -n $child ]] || continue
        old=$(git -C "$repo" rev-parse "refs/heads/$child")
        best=0
        best_count=-1
        for i in "${!olds[@]}"; do
            git -C "$repo" merge-base --is-ancestor "${olds[$i]}" "$old" || continue
            count=$(git -C "$repo" rev-list --count "$tip..${olds[$i]}")
            if (( count > best_count )); then
                best=$i
                best_count=$count
            fi
        done
        olds+=("$old")
        reason="下のブランチを付け替えられなかった"
        if [[ -n ${news[$best]} ]] && rebase_onto "$child" "${olds[$best]}" "${news[$best]}"; then
            news+=("$(git -C "$repo" rev-parse "refs/heads/$child")")
            if pushed=$(push_restacked "$child"); then
                echo "OK 付け替えた: ${child}（${pushed}）"
            else
                echo "NG 付け替えたが push できない: ${child}。origin が先に進んでいないかを確かめる。付け替える前の先頭: $old"
                failed=1
            fi
        else
            news+=("")
            echo "NG 付け替えなかった: ${child}（${reason}）。元のまま残した"
            failed=1
        fi
    done < <(stacked_on "$tip")
    return "$failed"
}

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <ブランチ名> <PR 番号>"; exit 1; }

use_repo "$1"
branch=$2
pr=$3
name=$(basename "$repo")

info=$(cd "$repo" && gh pr view "$pr" --json state,headRefOid,headRefName \
    -q '"\(.state) \(.headRefOid) \(.headRefName)"') || fail "PR #$pr を gh pr view で読めない"
read -r state head ref <<< "$info"
[[ $state == MERGED ]] || fail "PR #$pr が MERGED ではない（${state}）"
[[ $ref == "$branch" ]] || head=""
if [[ -n $head ]] && ! git -C "$repo" cat-file -e "$head^{commit}" 2>/dev/null; then
    git -C "$repo" fetch -q origin "pull/$pr/head" 2>/dev/null || true
fi

main=$(default_branch "$repo")
main=${main#origin/}
[[ $(git -C "$repo" branch --show-current) == "$main" ]] || fail "手元が $main ではない"
[[ -z $(git -C "$repo" status --porcelain) ]] || fail "手元に未 commit の変更がある"
git -C "$repo" pull -q --ff-only origin "$main" || fail "pull --ff-only が通らない"
[[ $(git -C "$repo" rev-parse HEAD) == $(git -C "$repo" rev-parse "origin/$main") ]] \
    || fail "手元の $main に、origin に無い commit がある"

tip=$head
if git -C "$repo" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    merged "$branch" "$head" "$main" || fail "$branch の中身が $main に入っていない。ワークツリーとブランチは残した"
    tip=$(git -C "$repo" rev-parse "refs/heads/$branch")
    worktree=$(worktree_of "$branch")
    [[ -z $worktree ]] || git -C "$repo" worktree remove "$worktree" 2>/dev/null \
        || fail "ワークツリーを消せない。未 commit や未追跡のファイルを確かめる: $worktree"
    git -C "$repo" branch -q -D "$branch"
fi

git -C "$repo" fetch -q --prune origin
remote=$(git -C "$repo" ls-remote --heads origin "$branch" | wc -l | tr -d ' ')
[[ $remote == 0 ]] && left="なし" || left="残っている"
derived=$(clean_derived_data)
echo "OK $name: $(git -C "$repo" rev-parse --short HEAD) | 手元の $main は origin と一致 | GitHub 上のブランチ: $left | 消した DerivedData: $derived"
if [[ -n $tip ]] && git -C "$repo" cat-file -e "$tip^{commit}" 2>/dev/null \
    && ! git -C "$repo" merge-base --is-ancestor "$tip" "origin/$main"; then
    temp_tree=""
    trap remove_temp_tree EXIT
    restack "$tip" || exit 1
fi
