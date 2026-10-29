#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ>"; exit 1; }

use_repo "$1"
base=$(git -C "$repo" merge-base "$2" HEAD)
shift 2

record=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-checks)
body=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-body.txt)

status=$("$(dirname "$0")/run-check.sh" "$repo" --status) || { grep '^NG' <<< "$status"; exit 1; }

{
    echo "## 🎯 目的"
    echo
    echo "<何がなぜ変わるかを 1〜2 文で>"
    echo
    echo "## 📝 変更"
    echo
    echo "| ファイル | 変えたこと |"
    echo "| --- | --- |"
    { git -C "$repo" diff --name-only "$base"; git -C "$repo" ls-files --others --exclude-standard; } \
        | sort -u | sed 's/|/\\|/g; s/.*/| `&` | |/'
    echo
    echo "## 🧪 確認"
    echo
    echo "| 確認 | 結果 |"
    echo "| --- | --- |"
    cut -f2 "$record" | sed 's/|/\\|/g; s/.*/| & | ✅ 通った |/'
    for item in "$@"; do
        echo "| ${item//|/\\|} | ⬜ 未検証 |"
    done
} >| "$body"

echo "$body"
