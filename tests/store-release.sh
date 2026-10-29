#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

listing="$root/skills/store-release/scripts/check-listing.py"
archive="$root/skills/store-release/scripts/archive-app.sh"

expect "NG 使い方" "archive-app: 引数が足りなければ NG" bash "$archive" a b
CC_STORE_EXPORT=x expect "NG CC_STORE_EXPORT は upload か export" "archive-app: 送り先が違えば NG" bash "$archive" a b "$work/out"
log="$work/archive.log"
printf 'x\na.swift:1: error: 型が無い\na.swift:1: error: 型が無い\nb.swift:2: warning: 使っていない\n' >"$log"
fail_with_log=$(awk '/^fail_with_log\(\) \{/,/^\}/' "$archive")
out=$(log=$log bash -c "source $root/lib/log.sh"$'\n'"${fail_with_log}"$'\nfail_with_log アーカイブ')
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

privacy="$root/skills/store-release/scripts/check-privacy.py"
write_manifest() {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>NSPrivacyAccessedAPITypes</key><array>%s</array></dict></plist>\n' "$2" >"$1/PrivacyInfo.xcprivacy"
}
declare_api() {
    echo "<dict><key>NSPrivacyAccessedAPIType</key><string>$1</string><key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array></dict>"
}
mkdir -p "$work/priv/App" "$work/priv/Empty"
echo 'let d = UserDefaults.standard' >"$work/priv/App/Store.swift"

expect "NG 使い方" "check-privacy: 引数が無ければ NG" python3 -I "$privacy"
expect "NG PrivacyInfo.xcprivacy が無い" "check-privacy: 申告のファイルが無ければ NG" python3 -I "$privacy" "$work/priv/Empty"
write_manifest "$work/priv" ""
expect "NG NSPrivacyAccessedAPICategoryUserDefaults" "check-privacy: 使っている API の申告が足りなければ NG" python3 -I "$privacy" "$work/priv"
write_manifest "$work/priv" "$(declare_api NSPrivacyAccessedAPICategoryUserDefaults)"
expect OK "check-privacy: 申告がそろっていれば OK" python3 -I "$privacy" "$work/priv"
write_manifest "$work/priv" "$(declare_api NSPrivacyAccessedAPICategorySystemBootTime)"
match "check-privacy: コードに無い申告は知らせる" "$(python3 -I "$privacy" "$work/priv")" "*-- NSPrivacyAccessedAPICategorySystemBootTime は申告しているが*"
echo 'garbage' >"$work/priv/PrivacyInfo.xcprivacy"
match "check-privacy: 壊れた申告のファイルは stdout に NG" "$(python3 -I "$privacy" "$work/priv" 2>/dev/null)" "NG*"
printf '<?xml version="1.0"?>\n<plist version="1.0"><dict>\n' >"$work/priv/PrivacyInfo.xcprivacy"
match "check-privacy: 途中で切れた XML の申告のファイルも stdout に NG" "$(python3 -I "$privacy" "$work/priv" 2>/dev/null)" "NG*"

finish
