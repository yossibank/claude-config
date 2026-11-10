#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../../lib/git.sh"

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ>"; exit 1; }

use_repo "$1"
base=$(merge_base_of "$repo" "$2") || { echo "$base"; exit 1; }
limit=200
risky='(^|/)(Migration|migrations?/)|[Ss]chema|\.sql$|fixtures/|\.pbxproj$|Package\.(swift|resolved)$|(^|/)hooks/|settings[^/]*\.json$'

changes() {
    local path count
    git -C "$repo" diff --numstat -z --no-renames "$base" | tr '\0' '\n' || return 1
    untracked_paths "$repo" | tr '\0' '\n' | while IFS= read -r path; do
        count=0
        [[ -f $repo/$path && -r $repo/$path ]] && count=$(wc -l < "$repo/$path" | tr -d ' ')
        printf '%s\t0\t%s\n' "$count" "$path"
    done
}

all_changes=$(changes) || { echo "NG $2 との差分を取れない"; exit 1; }

lines=0
files=0
docs_only=1
touched=()
if [[ -n $all_changes ]]; then
    while IFS=$'\t' read -r added deleted path; do
        [[ $added == - ]] && added=0 deleted=0
        files=$((files + 1))
        lines=$((lines + added + deleted))
        [[ $path == *.md || $path == docs/* ]] || docs_only=0
        [[ $path =~ $risky ]] && touched+=("$path")
    done <<< "$all_changes"
fi

[[ $files -gt 0 ]] || { echo "NG $2 との差分が無い"; exit 1; }

if [[ $docs_only == 1 ]]; then
    size=docs review="自分で見る"
elif [[ $lines -gt $limit || ${#touched[@]} -gt 0 ]]; then
    size=large review="reviewer（opus）"
else
    size=small review="reviewer（sonnet）"
fi

if [[ $size == docs ]] && grep -q '^verify-docs:' "$repo/Makefile" 2>/dev/null; then
    check="make verify-docs"
elif [[ $size == docs ]]; then
    check="変えた .md への docs-check.py"
elif grep -q '^verify:' "$repo/Makefile" 2>/dev/null; then
    check="make verify"
else
    check="CLAUDE.md の確認のコマンド"
fi

required=$(git_file "$repo" pr-required)
case $check in
    "make verify" | "make verify-docs") printf '%s\n' "$check" >| "$required" ;;
    *) rm -f "$required" ;;
esac

echo "$size | $lines 行 | 確認: $check | レビュー: $review"
[[ ${#touched[@]} -eq 0 ]] || printf '触れた所: %s\n' "${touched[@]}"
