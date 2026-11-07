#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

listing="$root/skills/store-release/scripts/check-listing.py"
archive="$root/skills/store-release/scripts/archive-app.sh"

expect "NG 使い方" "archive-app: 引数が足りなければ NG" bash "$archive" a b
CC_STORE_EXPORT=export expect "NG CC_STORE_EXPORT と CC_STORE_ARCHIVE_ONLY は読まない" "archive-app: 前の変数が付いていれば、送らずに NG" bash "$archive" a b "$work/out"
CC_STORE_DESTINATION=x expect "NG CC_STORE_DESTINATION は upload・export・archive" "archive-app: 行き先が違えば NG" bash "$archive" a b "$work/out"
source "$root/tests/lib/fixtures.sh"
fake_command xcodebuild 'echo "$*" >>"'"$work"'/xcodebuild.args"; [[ " $* " != *" -showBuildSettings "* ]] || echo "    DEVELOPMENT_TEAM = TEAM1"'
check "archive-app: 送れたら行き先とログの場所を OK で出す" grep -qxF "OK upload（ログ: $work/out/archive.log）" <<<"$(bash "$archive" a b "$work/out")"
check "archive-app: 署名のチームを書き出しの設定に入れる" grep -qF "<string>TEAM1</string>" "$work/out/ExportOptions.plist"
: >|"$work/xcodebuild.args"
check "archive-app: archive ならアーカイブだけを作る" grep -qxF "OK アーカイブ $work/out/b.xcarchive" <<<"$(CC_STORE_DESTINATION=archive bash "$archive" a b "$work/out")"
check "archive-app: archive なら書き出さない" test -z "$(grep -e -exportArchive "$work/xcodebuild.args")"
log="$work/archive.log"
printf 'x\na.swift:1: error: 型が無い\na.swift:1: error: 型が無い\nb.swift:2: warning: 使っていない\n' >"$log"
fail_with_log=$(awk '/^fail_with_log\(\) \{/,/^\}/' "$archive")
out=$(log=$log bash -c "source $root/lib/build_log.sh"$'\n'"${fail_with_log}"$'\nfail_with_log アーカイブ')
status=$?
check "archive-app: 失敗したら終了コード 1 で終える" test "$status" -eq 1
check "archive-app: ログの error の行を 1 回ずつ出す" test "$(grep -c 'error: 型が無い' <<<"$out")" -eq 1
check "archive-app: warning の行は出さない" test -z "$(grep warning <<<"$out")"
check "archive-app: 何が失敗したかとログの場所を NG で出す" grep -qxF "NG アーカイブ（ログ: ${log}）" <<<"$out"
source "$root/lib/build_log.sh"
{ for n in $(seq 1 25); do echo "c.swift:$n: error: $n 番目"; done; echo '** TEST FAILED **'; echo 'ErrorView.swift をコンパイル'; } >"$work/many.log"
check "show_errors: first は最初のエラーから出す" grep -q 'c.swift:1: error' <<<"$(show_errors "$work/many.log" first)"
check "show_errors: 既定は最後の行まで出し、大文字の FAILED も拾う" grep -qF '** TEST FAILED **' <<<"$(show_errors "$work/many.log")"
check "show_errors: ファイル名の Error には当たらない" test -z "$(show_errors "$work/many.log" | grep ErrorView)"
fake_command xcodebuild 'exit 65'
expect "NG DEVELOPMENT_TEAM が見つからない" "archive-app: 設定を読めなければ黙って落ちずに NG" bash "$archive" a b "$work/out"
screenshot="$root/skills/store-release/scripts/take-screenshot.sh"
fake_command xcrun 'exit 1'
expect "NG シミュレーターが起動しない: udid" "take-screenshot: 起動を待てなければ黙って落ちずに NG" bash "$screenshot" udid "$work/shot.png"
fake_command xcrun 'exit 0'
fake_command sips 'exit 1'
expect "NG 画像の大きさを読めない" "take-screenshot: 大きさを読めなければ黙って落ちずに NG" bash "$screenshot" udid "$work/shot.png"
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

pages="$root/skills/store-release/scripts/create-custom-pages.py"
export https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9
unset ASC_ISSUER_ID ASC_KEY_ID ASC_KEY_PATH ASC_VENDOR_NUMBER

repo="$work/pages"
mkdir -p "$repo/store/shots"
printf '123456\n' >"$repo/store/app-id.txt"
touch "$repo/store/shots/01-a.png" "$repo/store/shots/02-b.png" "$repo/store/shots/03-c.png"
write_plan() {
    printf '{"locale": "ja", "screenshots": {"APP_IPHONE_67": "shots"}, "pages": [%s]}\n' "$1" >"$repo/store/custom-pages.json"
}
page_a='{"name": "節約", "keywords": ["家計簿"], "promotionalText": "毎日の支出を記録", "lead": ["03-c.png"]}'

expect "NG 使い方" "create-custom-pages: 引数が無ければ NG" python3 -I "$pages"

write_plan "$page_a"
match "create-custom-pages: --dry-run は lead の画像を先頭に並べて作る予定を出す" \
    "$(python3 -I "$pages" "$repo" --dry-run)" "*OK 作る予定:*03-c.png → 01-a.png → 02-b.png*"

rm "$repo/store/custom-pages.json"
expect "ページの案のファイルが無い" "create-custom-pages: 案のファイルが無ければ NG" python3 -I "$pages" "$repo" --dry-run

write_plan '{"name": "節約", "keywords": ["家計簿"]}, {"name": "支出", "keywords": ["家計簿"]}'
expect "ほかのページと語が重なっている" "create-custom-pages: 同じキーワードが 2 ページにあれば NG" python3 -I "$pages" "$repo" --dry-run

write_plan '{"name": "節約", "keywords": ["家計簿"]}, {"name": "節約", "keywords": ["支出"]}'
expect "同じ name のページが 2 つある" "create-custom-pages: 同じ name のページが 2 つあれば NG" python3 -I "$pages" "$repo" --dry-run

write_plan '{"name": "節約", "keywords": ["家計簿"], "lead": ["99-z.png"]}'
expect "のフォルダに無い画像" "create-custom-pages: lead にフォルダに無い画像があれば NG" python3 -I "$pages" "$repo" --dry-run

long=$(printf 'あ%.0s' $(seq 171))
write_plan "{\"name\": \"節約\", \"keywords\": [\"家計簿\"], \"promotionalText\": \"$long\"}"
expect "170 字まで" "create-custom-pages: promotionalText が 171 字なら NG" python3 -I "$pages" "$repo" --dry-run

write_plan "$page_a"
expect "環境変数が無い" "create-custom-pages: --dry-run 無しで ASC_* が無ければ NG" python3 -I "$pages" "$repo"

# 引数: 案のあるリポジトリ、シナリオ（unapproved・existing・new）
run_pages() {
    ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH=z python3 -I - "$root" "$pages" "$repo" "$1" 2>&1 <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_module

module = load_module(sys.argv[2])
repo, scenario = sys.argv[3], sys.argv[4]
approved = {"unapproved": []}.get(scenario, [{"id": "家計簿"}])
names = [{"id": "p1", "attributes": {"name": "節約"}}] if scenario in ("existing", "partial") else []
shots = [{"id": "x"}] * (3 if scenario == "existing" else 1)
calls = []


def fake(url, body=None, method=None):
    calls.append((method or ("POST" if body else "GET"), url, body))
    if "READY_FOR_SALE" in url:
        return {"data": [{"id": "v1"}]}
    if url.endswith("/appStoreVersionLocalizations?filter%5Blocale%5D=ja"):
        return {"data": [{"id": "l1"}]}
    if url.startswith("/v1/appStoreVersionLocalizations/l1/searchKeywords"):
        return {"data": approved, "links": {}}
    if url.startswith("/v1/apps/123456/appCustomProductPages"):
        return {"data": names, "links": {}}
    if url == "/v1/appCustomProductPages":
        return {"data": {"id": "p1"}}
    if url == "/v1/appCustomProductPages/p1/appCustomProductPageVersions":
        return {"data": [{"id": "pv1"}]}
    if url == "/v1/appCustomProductPageVersions/pv1/appCustomProductPageLocalizations":
        if scenario == "broken":
            return {}
        return {"data": [{"id": "pl1", "attributes": {"locale": "ja"}}]}
    if url.startswith("/v1/appCustomProductPageLocalizations/pl1/searchKeywords?"):
        return {"data": approved, "links": {}}
    if url.startswith("/v1/appCustomProductPageLocalizations/pl1/appScreenshotSets?"):
        return {"data": [{"id": "s1", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"}}], "links": {}}
    if url.startswith("/v1/appScreenshotSets/s1/appScreenshots?"):
        return {"data": shots, "links": {}}
    if url == "/v1/appScreenshotSets":
        return {"data": {"id": "s1"}}
    if url == "/v1/appScreenshots":
        return {"data": {"id": "shot1", "attributes": {"uploadOperations": [{"url": "u", "method": "PUT", "offset": 0, "length": 0}]}}}
    return {"data": {}}


module.asc_json = fake
sys.modules["app_store"].asc_json = fake
module.asc_request = lambda url, body=None, **kwargs: calls.append(("REQUEST", url, body))
module.put_parts = lambda operations, data: calls.append(("PUT", "parts", None))
sys.argv = ["create-custom-pages.py", repo]
try:
    module.main()
except SystemExit:
    pass
for method, url, body in calls:
    print(f"CALL {method} {url}")
    if url.endswith("relationships/searchKeywords"):
        print(f"KEYWORDS {body['data'][0]['id']}")
    if method == "PATCH":
        print(f"CHECKSUM {body['data']['attributes']['sourceFileChecksum']}")
EOF
}

out=$(run_pages unapproved)
match "create-custom-pages: 配信中の版に無い語は NG で、ページを作る POST をしない" "$out" "*NG 節約: 配信中の版のキーワードに無い語: 家計簿*"
check "create-custom-pages: 語が通らなければ appCustomProductPages に POST しない" test -z "$(grep -x 'CALL POST /v1/appCustomProductPages' <<<"$out")"

match "create-custom-pages: 既にある名前のページは、中身がそろっていれば作らない" "$(run_pages existing)" "*OK 節約 は既にあるので作らなかった*"
match "create-custom-pages: 既にある名前のページでも、画像が足りなければ途中で止まったものとして NG" "$(run_pages partial)" "*NG 節約 は既にあるが、途中で止まったままになっている（APP_IPHONE_67 の画像が 1 枚で、3 枚に足りない）*"
match "create-custom-pages: 作る途中の想定外の例外でも、途中のページが残った案内を出す" "$(run_pages broken)" "*NG 節約 を作る途中で止まった: KeyError。App Store Connect で途中のページを消してから*"

out=$(run_pages new)
check "create-custom-pages: 新しいページは POST で作る" grep -qx 'CALL POST /v1/appCustomProductPages' <<<"$out"
check "create-custom-pages: キーワードを searchKeywords の関係に入れる" grep -qx 'KEYWORDS 家計簿' <<<"$out"
check "create-custom-pages: 画像を PATCH で確定し、md5 の sourceFileChecksum を付ける" grep -qx 'CHECKSUM d41d8cd98f00b204e9800998ecf8427e' <<<"$out"
check "create-custom-pages: 画像の確定は appScreenshots/<id> への PATCH" grep -qx 'CALL PATCH /v1/appScreenshots/shot1' <<<"$out"

mkdir -p "$work/priv2/App" "$work/priv2/Pods" "$work/priv2/build"
write_manifest "$work/priv2" "<string>x</string>"
printf '// UserDefaults は使わない\nlet note = "UserDefaults"\nlet s = url.stat(path)\nlet t = "\\(a ? "UserDefaults" : "b")"\n' >"$work/priv2/App/Note.swift"
echo 'let d = UserDefaults.standard' >"$work/priv2/Pods/Lib.swift"
echo 'let d = UserDefaults.standard' >"$work/priv2/build/Gen.swift"
expect OK "check-privacy: コメントと文字列の中の語、x.stat(、Pods と build、dict でない申告の要素は見ない" python3 -I "$privacy" "$work/priv2"
echo 'let n = stat(path, &info)' >"$work/priv2/App/Call.swift"
expect "NG NSPrivacyAccessedAPICategoryFileTimestamp" "check-privacy: C の stat( の呼び出しは申告を求める" python3 -I "$privacy" "$work/priv2"

mkdir -p "$work/odd/name.txt"
expect "想定外の失敗" "check-listing: 想定外の例外は traceback にせず NG にする" python3 -I "$listing" "$work/odd"
printf '家計簿,\n節約\n' >"$folder/keywords.txt"
expect "改行がある" "check-listing: keywords.txt の途中の改行は NG" python3 -I "$listing" "$folder"

fake_command xcrun 'echo "$*" >>"'"$work"'/xcrun.log"'
fake_command sips 'exit 1'
bash "$screenshot" udid "$work/shot.png" >/dev/null 2>&1
check "take-screenshot: 終わったらステータスバーの固定を戻す" grep -qx "simctl status_bar udid clear" "$work/xcrun.log"

finish
