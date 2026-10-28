#!/bin/bash
set -euo pipefail

[[ $# -ge 4 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ> <PR のタイトル> <本文のファイル>"; exit 1; }

repo=$(cd "$1" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || { echo "NG Git のリポジトリではない: $1"; exit 1; }
base=$2
title=$3
body=$4
branch=$(git -C "$repo" branch --show-current)

info=$("$(dirname "$0")/repo-access.sh" "$repo") || { echo "$info"; exit 1; }
read -r owner name access <<< "$info"
slug="$owner/$name"

case $access in
    write)
        echo "gh"
        ;;
    *)
        query=$(jq -rn --arg title "$title" --rawfile body "$body" '"title=\($title | @uri)&body=\($body | @uri)"')
        echo "compare https://github.com/$slug/compare/$base...$branch?expand=1&$query"
        ;;
esac
