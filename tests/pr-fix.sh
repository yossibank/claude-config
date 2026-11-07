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
status=$?
if [[ $status == 0 && $out == *"ACCESS write"* && $out == *"CI NG build"* && $out == *"THREAD T1"* && $out == *"REVIEW COMMENTED"* && $out == *"COMMENT @someone"* ]]; then
    ok "fetch-threads: 権限と落ちた CI と、めくって集めた未解決のスレッドとレビューとコメントを出す"
else
    ng "fetch-threads: 権限と落ちた CI と、めくって集めた未解決のスレッドとレビューとコメントを出す（終了コード ${status}）" "$out"
fi

finish
