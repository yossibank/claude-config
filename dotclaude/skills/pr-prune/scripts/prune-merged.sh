#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../../lib/git.sh"

fail() {
    echo "NG $name: $1"
    exit 1
}

owned() {
    case $1 in
        "$repo" | "$repo"/* | "$(worktree_root "$name")"/*) return 0 ;;
    esac
    return 1
}

in_main() {
    case $1 in
        "$repo/.claude" | "$repo/.claude"/*) return 1 ;;
        "$repo" | "$repo"/*) return 0 ;;
    esac
    return 1
}

expired() {
    [[ ! -e $1 ]] || { [[ $low == 1 ]] && in_main "$1"; }
}

# 外付けのボリュームが外れている間は、フォルダが見えないだけで、消えたとは限らない
mounted() {
    local volume
    case $1 in
        /Volumes/*)
            volume=${1#/Volumes/}
            [[ -d /Volumes/${volume%%/*} ]]
            return
            ;;
    esac
    return 0
}

free_gb() {
    df -Pk "$HOME" | awk 'NR == 2 { print int($4 / 1048576) }'
}

derived_plists() {
    local plist path

    for plist in "$HOME"/Library/Developer/Xcode/DerivedData/*/info.plist; do
        path=$(plutil -extract WorkspacePath raw "$plist" 2>/dev/null) || continue
        printf '%s\t%s\n' "$path" "$(dirname "$plist")"
    done
}

remove_copy() {
    local path dir

    while IFS=$'\t' read -r path dir; do
        [[ $path == "$1"/* ]] && rm -rf "$dir"
    done < <(derived_plists)

    rm -rf "$1" "$1.origin"
}

clean_snapshots() {
    local origin_file copy origin legacy
    local count=0

    for origin_file in "$snapshots"/*.origin; do
        [[ -f $origin_file ]] || continue
        copy=${origin_file%.origin}
        origin=$(<"$origin_file")
        owned "$origin" && mounted "$origin" || continue
        expired "$origin" && mkdir "$copy.lock" 2>/dev/null || continue
        echo $$ >"$copy.lock/pid"
        remove_copy "$copy"
        rm -rf "$copy.lock"
        count=$((count + 1))
    done

    legacy="$snapshots/$(basename "$repo")-$(printf '%s' "$repo" | shasum | cut -c1-12)"
    if [[ $low == 1 && -d $legacy ]] && mkdir "$legacy.lock" 2>/dev/null; then
        echo $$ >"$legacy.lock/pid"
        remove_copy "$legacy"
        rm -rf "$legacy.lock"
        count=$((count + 1))
    fi

    echo "$count"
}

clean_derived_data() {
    local path dir
    local count=0

    while IFS=$'\t' read -r path dir; do
        owned "$path" && mounted "$path" && expired "$path" || continue
        rm -rf "$dir"
        count=$((count + 1))
    done < <(derived_plists)

    echo "$count"
}

clean_package_builds() {
    local list build
    local count=0

    list=$(find "$repo" \( -name .git -o -name node_modules -o -name Pods -o -path "$repo/.claude" \) -prune \
        -o -type d -name .build -prune -print) || { echo "確かめられなかった"; return; }

    while IFS= read -r build; do
        [[ -n $build ]] || continue
        rm -rf "$build"
        count=$((count + 1))
    done <<<"$list"

    echo "$count"
}

clean_simulators() {
    command -v xcrun >/dev/null || { echo "確かめられなかった"; return; }
    xcrun simctl delete unavailable >/dev/null 2>&1 && echo "消した" || echo "消せなかった"
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
snapshots=${CC_UI_WORK_DIR:-$HOME/Library/Caches/ui-snapshot}
before=$(free_gb)
min_free=${CC_PRUNE_MIN_FREE_GB:-20}
[[ $min_free =~ ^[0-9]+$ ]] || min_free=20
low=0
[[ -n $before ]] && ((before < min_free)) && low=1
copies=$(clean_snapshots)
derived=$(clean_derived_data)
builds=$(clean_package_builds)
simulators=$(clean_simulators)
[[ $low == 1 ]] && scope="空きが少ないので、本体の DerivedData と写しも消した" || scope="DerivedData と写しは、ワークツリーの分だけ消した"
echo "OK $name: $(git -C "$repo" rev-parse --short HEAD) | 手元の $main は origin と一致 | GitHub 上のブランチ: $left | 消した DerivedData: $derived"
echo "OK 掃除: $scope | 写し（中の DerivedData ごと）: $copies | .build: $builds | 使えないシミュレーター: $simulators | 空き: ${before:-?} GB → $(free_gb) GB"
base_ref=${base_ref:-$main}
if [[ -n $tip ]] && git -C "$repo" cat-file -e "$tip^{commit}" 2>/dev/null \
    && git -C "$repo" rev-parse -q --verify "origin/$base_ref" >/dev/null \
    && ! git -C "$repo" merge-base --is-ancestor "$tip" "origin/$base_ref"; then
    "$(dirname "$0")/replace-base.sh" "$repo" "$tip" "$base_ref" "$main" || exit 1
fi
