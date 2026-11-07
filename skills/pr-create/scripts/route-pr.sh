#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 4 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <base のブランチ> <PR のタイトル> <本文のファイル>"; exit 1; }

use_repo "$1"
base=$2
title=$3
body=$4
branch=$(git -C "$repo" branch --show-current)
[[ -n $branch ]] || { echo "NG ブランチが無い（detached HEAD）。ブランチに切り替えてから出す"; exit 1; }

info=$(repo_access "$repo") || { echo "$info"; exit 1; }
read -r owner name access <<< "$info"
slug="$owner/$name"

case $access in
    write)
        echo "gh"
        ;;
    *)
        query=$(jq -rn --arg title "$title" --rawfile body "$body" '"title=\($title | @uri)&body=\($body | @uri)"')
        if (( ${#query} > 6000 )); then
            query=$(jq -rn --arg title "$title" '"title=\($title | @uri)"')
            echo "本文が長く URL に入らないので、本文は貼ってもらう: $body" >&2
        fi
        echo "compare https://github.com/$slug/compare/$base...$branch?expand=1&$query"
        ;;
esac
