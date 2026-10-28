#!/bin/bash
set -euo pipefail

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ>"; exit 1; }

repo=$(cd "$1" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || { echo "NG Git のリポジトリではない: $1"; exit 1; }
base=$(git -C "$repo" merge-base "$2" HEAD)
limit=200
risky='(^|/)(Migration|migrations?/)|[Ss]chema|\.sql$|fixtures/|\.pbxproj$|Package\.(swift|resolved)$|(^|/)hooks/|settings[^/]*\.json$'

changes() {
    git -C "$repo" diff --numstat -z --no-renames "$base" | tr '\0' '\n'
    git -C "$repo" ls-files -z --others --exclude-standard | while IFS= read -r -d '' path; do
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
    check="変えた .md への docs-check.py"
elif grep -q '^verify:' "$repo/Makefile" 2>/dev/null; then
    check="make verify"
else
    check="CLAUDE.md の確認のコマンド"
fi

echo "$size | $lines 行 | 確認: $check | レビュー: $review"
[[ ${#touched[@]} -eq 0 ]] || printf '触れた所: %s\n' "${touched[@]}"
