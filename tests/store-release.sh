#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

listing="$root/skills/store-release/scripts/check-listing.py"
archive="$root/skills/store-release/scripts/archive-app.sh"

expect "NG 使い方" "archive-app: 引数が足りなければ NG" bash "$archive" a b
EXPORT_DESTINATION=x expect "NG EXPORT_DESTINATION は upload か export" "archive-app: 送り先が違えば NG" bash "$archive" a b "$work/out"
log="$work/archive.log"
printf 'x\na.swift:1: error: 型が無い\na.swift:1: error: 型が無い\nb.swift:2: warning: 使っていない\n' >"$log"
fail_with_log=$(awk '/^fail_with_log\(\) \{/,/^\}/' "$archive")
out=$(log=$log bash -c "${fail_with_log}"$'\nfail_with_log アーカイブ')
status=$?
check "archive-app: 失敗したら終了コード 1 で終える" test "$status" -eq 1
check "archive-app: ログの error の行を 1 回ずつ出す" test "$(grep -c 'error: 型が無い' <<<"$out")" -eq 1
check "archive-app: warning の行は出さない" test -z "$(grep warning <<<"$out")"
check "archive-app: 何が失敗したかとログの場所を NG で出す" grep -qxF "NG アーカイブ（全ログ: ${log}）" <<<"$out"
folder="$work/ja"
mkdir -p "$folder"
printf 'カケイボ\n' >"$folder/name.txt"
printf '毎日の支出を記録する\n' >"$folder/subtitle.txt"
printf '家計簿,節約,支出\n' >"$folder/keywords.txt"
printf '支出を記録して、月ごとに振り返るアプリ。\n' >"$folder/description.txt"
printf 'https://example.com/support\n' >"$folder/support_url.txt"
printf 'https://example.com/privacy\n' >"$folder/privacy_url.txt"

expect "NG 使い方" "check-listing: 引数が無ければ NG" python3 -I "$listing"
expect OK "check-listing: そろった掲載情報は通る" python3 -I "$listing" "$folder"

printf '%031d\n' 0 >"$folder/name.txt"
expect "name.txt が 31 字" "check-listing: 字数の上限を超えたら NG" python3 -I "$listing" "$folder"
printf 'カケイボ\n' >"$folder/name.txt"

printf 'http://example.com/support\n' >"$folder/support_url.txt"
expect "https:// で始まらない" "check-listing: https ではない URL は NG" python3 -I "$listing" "$folder"
printf 'https://example.com/support\n' >"$folder/support_url.txt"

printf '家計簿, 節約\n' >"$folder/keywords.txt"
expect "空白がある" "check-listing: キーワードのカンマの後の空白は NG" python3 -I "$listing" "$folder"
printf '家計簿,節約\n' >"$folder/keywords.txt"

rm -f "$folder/subtitle.txt"
expect "subtitle.txt が無い" "check-listing: 要るファイルが無ければ NG" python3 -I "$listing" "$folder"

finish
