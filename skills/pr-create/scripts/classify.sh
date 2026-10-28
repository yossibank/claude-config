#!/bin/bash
set -euo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
base=$(git -C "$repo" merge-base "${2:?base のブランチを渡す}" HEAD)
limit=200
risky='(^|/)(Migration|migrations?/)|[Ss]chema|\.sql$|fixtures/|\.pbxproj$|Package\.(swift|resolved)$|(^|/)hooks/|settings[^/]*\.json$'

changes() {
    git -C "$repo" diff --numstat --no-renames "$base"
    git -C "$repo" ls-files --others --exclude-standard | while read -r path; do
        printf '%s\t0\t%s\n' "$(wc -l < "$repo/$path" | tr -d ' ')" "$path"
    done
}

lines=0
docs_only=1
touched=()
while IFS=$'\t' read -r added deleted path; do
    [[ $added == - ]] && added=0 deleted=0
    lines=$((lines + added + deleted))
    [[ $path == *.md || $path == docs/* ]] || docs_only=0
    [[ $path =~ $risky ]] && touched+=("$path")
done < <(changes)

[[ $lines -gt 0 ]] || { echo "NG $2 との差分が無い"; exit 1; }

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
    check="変えた .md への post-edit-check-docs.py"
elif grep -q '^verify:' "$repo/Makefile" 2>/dev/null; then
    check="make verify"
else
    check="CLAUDE.md の確認のコマンド"
fi

echo "$size | $lines 行 | 確認: $check | レビュー: $review"
[[ ${#touched[@]} -eq 0 ]] || printf '触れた所: %s\n' "${touched[@]}"
