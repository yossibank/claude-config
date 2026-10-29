#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

threads="$root/skills/pr-fix/scripts/list-threads.sh"
repo="$work/repo"
clone_with_origin "$repo"
fake_gh 'case "$1 $2" in
    "repo view") echo "o n WRITE" ;;
    "pr checks") echo "CI NG build https://ci.example.com/1"; exit 8 ;;
    "api graphql") echo "THREAD T1 a.swift:3 @reviewer: 直す" ;;
esac'

expect "NG 使い方" "list-threads: 引数が足りなければ NG" bash "$threads" "$repo"
out=$(bash "$threads" "$repo" 1)
status=$?
if [[ $status == 0 && $out == *"ACCESS write"* && $out == *"CI NG build"* && $out == *"THREAD T1"* ]]; then
    ok "list-threads: 権限と落ちた CI と未解決のスレッドを出す"
else
    ng "list-threads: 権限と落ちた CI と未解決のスレッドを出す（終了コード ${status}）" "$out"
fi

finish
