#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 4 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ> <PR のタイトル> <本文のファイル>"; exit 1; }

repo=$(resolve_repo "$1") || { echo "$repo"; exit 1; }
base=$2
title=$3
body=$4
branch=$(git -C "$repo" branch --show-current)

info=$(repo_access "$repo") || { echo "$info"; exit 1; }
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
