#!/bin/bash
set -euo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
base=$(git -C "$repo" merge-base "${2:?base のブランチを渡す}" HEAD)
shift 2

record=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-checks)
body=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-body.txt)
state=$("$(dirname "$0")/state.sh" "$repo")

[[ -s $record ]] || { echo "NG check.sh で通した確認が無い"; exit 1; }
failed=$(awk -F '\t' '$1 != "OK" {print $2}' "$record" | paste -sd ',' -)
[[ -z $failed ]] || { echo "NG 通っていない確認がある: $failed"; exit 1; }
stale=$(awk -F '\t' -v state="$state" '$3 != state {print $2}' "$record" | paste -sd ',' -)
[[ -z $stale ]] || { echo "NG 確認の後に変更がある。通し直す: $stale"; exit 1; }

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
