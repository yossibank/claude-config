#!/bin/bash
set -euo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
base=${2:?base のブランチを渡す}
title=${3:?PR のタイトルを渡す}
body=${4:?本文のファイルを渡す}
branch=$(git -C "$repo" branch --show-current)

info=$(cd "$repo" && gh repo view --json nameWithOwner,viewerPermission \
    -q '"\(.nameWithOwner) \(.viewerPermission)"') || { echo "NG gh repo view が通らない"; exit 1; }
read -r slug permission <<< "$info"

case $permission in
    ADMIN | MAINTAIN | WRITE)
        echo "gh"
        ;;
    *)
        query=$(jq -rn --arg title "$title" --rawfile body "$body" '"title=\($title | @uri)&body=\($body | @uri)"')
        echo "compare https://github.com/$slug/compare/$base...$branch?expand=1&$query"
        ;;
esac
