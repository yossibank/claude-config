#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

listing="$root/skills/store-release/scripts/check-listing.py"
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
