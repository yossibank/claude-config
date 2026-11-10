#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"

threads="$root/dotclaude/skills/pr-fix/scripts/fetch-threads.sh"
repo="$work/repo"
clone_with_origin "$repo"
# gh の JSON を返し、-q の式は本物の jq で絞る。未解決だけを選ぶ式も走る
fake_gh 'query=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    [[ ${args[i]} == -q ]] && query=${args[i + 1]}
done
emit() { if [[ -n $query ]]; then jq -r "$query" <<<"$1"; else echo "$1"; fi; }
case "$1 $2" in
    "repo view") echo "o n ${GH_ACCESS:-WRITE}" ;;
    "pr checks")
        case ${GH_CHECKS:-fail} in
            fail) emit "[{\"name\": \"build\", \"bucket\": \"fail\", \"link\": \"https://ci.example.com/1\"}, {\"name\": \"lint\", \"bucket\": \"pass\", \"link\": \"x\"}]"; exit 8 ;;
            none) echo "no checks reported on the branch" >&2; exit 1 ;;
            *) echo "HTTP 500" >&2; exit 1 ;;
        esac ;;
    "api graphql")
        if [[ $* == *reviewThreads* ]]; then
            emit "{\"data\": {\"repository\": {\"pullRequest\": {\"reviewThreads\": {\"nodes\": [
              {\"id\": \"T1\", \"isResolved\": false, \"path\": \"a.swift\", \"line\": 3, \"comments\": {\"nodes\": [{\"author\": {\"login\": \"reviewer\"}, \"body\": \"直す\\n詳しく\"}]}},
              {\"id\": \"T2\", \"isResolved\": true, \"path\": \"b.swift\", \"line\": 1, \"comments\": {\"nodes\": []}}]}}}}}"
        elif [[ $* == *"reviews(first: 100"* ]]; then
            emit "{\"data\": {\"repository\": {\"pullRequest\": {\"reviews\": {\"nodes\": [
              {\"author\": {\"login\": \"reviewer\"}, \"state\": \"COMMENTED\", \"body\": \"全体\", \"url\": \"https://r/1\"},
              {\"author\": {\"login\": \"bot\"}, \"state\": \"APPROVED\", \"body\": \"\", \"url\": \"https://r/2\"}]}}}}}"
        elif [[ $* == *"comments(first: 100"* ]]; then
            emit "{\"data\": {\"repository\": {\"pullRequest\": {\"comments\": {\"nodes\": [
              {\"author\": {\"login\": \"someone\"}, \"body\": \"質問\", \"url\": \"https://c/1\"}]}}}}}"
        fi ;;
esac'

expect "NG 使い方" "fetch-threads: 引数が足りなければ NG" bash "$threads" "$repo"
out=$(bash "$threads" "$repo" 1)
check "fetch-threads: 終了コード 0 で終わる" test $? -eq 0
for want in "ACCESS write" "CI NG build https://ci.example.com/1" "THREAD T1 a.swift:3 @reviewer: 直す" "REVIEW COMMENTED @reviewer: 全体 https://r/1" "COMMENT @someone: 質問 https://c/1"; do
    check "fetch-threads: ${want} を出す" grep -qF "$want" <<<"$out"
done
check "fetch-threads: 解決済みのスレッドは出さない" test -z "$(grep T2 <<<"$out")"
check "fetch-threads: 本文のないレビューは出さない" test -z "$(grep APPROVED <<<"$out")"
check "fetch-threads: 通った確認は出さない" test -z "$(grep lint <<<"$out")"
check "fetch-threads: 本文は 1 行目だけにする" test -z "$(grep 詳しく <<<"$out")"

out=$(GH_ACCESS=READ bash "$threads" "$repo" 1)
check "fetch-threads: 読むだけの権限なら、返信と解決は人がすると知らせる" grep -qF "ACCESS read（返信と解決は人がする）" <<<"$out"

out=$(GH_CHECKS=none bash "$threads" "$repo" 1)
check "fetch-threads: 確認が無い PR は、確認の行を出さずにスレッドを集める" test -z "$(grep '^CI' <<<"$out")"
check "fetch-threads: 確認が無くてもスレッドを出す" grep -qF "THREAD T1" <<<"$out"
GH_CHECKS=error expect "NG gh pr checks が通らない" "fetch-threads: 確認の取得が別の理由で失敗したら NG" bash "$threads" "$repo" 1

finish
