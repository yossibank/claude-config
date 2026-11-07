#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

threads="$root/skills/pr-fix/scripts/fetch-threads.sh"
repo="$work/repo"
clone_with_origin "$repo"
fake_gh 'case "$1 $2" in
    "repo view") echo "o n WRITE" ;;
    "pr checks") echo "CI NG build https://ci.example.com/1"; exit 8 ;;
    "api graphql")
        if [[ $* == *reviewThreads* ]]; then
            echo "THREAD T1 a.swift:3 @reviewer: 直す"
        elif [[ $* == *"reviews(first: 100, after: \$endCursor)"* && $3 == --paginate ]]; then
            echo "REVIEW COMMENTED @reviewer: 全体"
        elif [[ $* == *"comments(first: 100, after: \$endCursor)"* && $3 == --paginate ]]; then
            echo "COMMENT @someone: 質問"
        fi ;;
esac'

expect "NG 使い方" "fetch-threads: 引数が足りなければ NG" bash "$threads" "$repo"
out=$(bash "$threads" "$repo" 1)
check "fetch-threads: 終了コード 0 で終わる" test $? -eq 0
for want in "ACCESS write" "CI NG build" "THREAD T1" "REVIEW COMMENTED" "COMMENT @someone"; do
    check "fetch-threads: ${want} を出す" grep -qF "$want" <<<"$out"
done

finish
