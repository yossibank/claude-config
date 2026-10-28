#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ>"; exit 1; }

repo=$(resolve_repo "$1") || { echo "$repo"; exit 1; }
base=$(git -C "$repo" merge-base "$2" HEAD)
shift 2

record=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-checks)
body=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-body.txt)

status=$("$(dirname "$0")/check.sh" "$repo" --status) || { grep '^NG' <<< "$status"; exit 1; }

{
    echo "<何がなぜ変わるかを 1〜2 文で>"
    echo
    echo "## 変更"
    { git -C "$repo" diff --name-only "$base"; git -C "$repo" ls-files --others --exclude-standard; } \
        | sort -u | sed 's/.*/- `&`：/'
    echo
    echo "## 確認"
    cut -f2 "$record" | sed 's/^/- [x] /'
    for item in "$@"; do
        echo "- [ ] ${item}（未検証）"
    done
} >| "$body"

echo "$body"
