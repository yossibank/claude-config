#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/http_fake.sh"

scripts="$root/skills/app-plan/scripts"
offline

expect "NG 使い方" "fetch-rival-reviews: 引数が無ければ NG" python3 -I "$scripts/fetch-rival-reviews.py"
expect "NG 使い方" "fetch-rival-reviews: 数字でないアプリの ID は NG" python3 -I "$scripts/fetch-rival-reviews.py" abc
expect "NG 使い方" "fetch-rival-reviews: 数字でない星の上限は NG" python3 -I "$scripts/fetch-rival-reviews.py" 123 x
expect "NG レビューを読めなかった" "fetch-rival-reviews: 通信できなければ NG" python3 -I "$scripts/fetch-rival-reviews.py" 123
rival_run() {
    python3 -I - "$root" "$scripts/fetch-rival-reviews.py" "$@" 2>&1 <<'EOF'
import os
import sys
import urllib.error
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

reviews = load_module(sys.argv[2])
entry = lambda rating, text: {"im:rating": {"label": rating}, "title": {"label": "t" + rating}, "content": {"label": text}}


def route(method, url, body):
    if "/page=1/" in url:
        return {"feed": {"entry": [entry("1", "ひどい"), entry("5", "最高")]}}
    if "/page=2/" in url:
        raise TimeoutError()
    return None


install(route)
sys.argv = ["fetch-rival-reviews.py", *sys.argv[3:]]
reviews.main()
report_unknown()
EOF
}
out=$(rival_run 123)
check "fetch-rival-reviews: 星の上限以下のレビューを、星・題・本文で出す" grep -qx $'1\tt1\tひどい' <<<"$out"
check "fetch-rival-reviews: 星の上限を超えるレビューは出さない" test -z "$(grep 最高 <<<"$out")"
check "fetch-rival-reviews: 星の上限を渡せば、その星まで出す" grep -q $'^5\tt5\t最高' <<<"$(rival_run 123 5)"
check "fetch-rival-reviews: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$out")"
check "fetch-rival-reviews: 2 ページ目から先を読めなければ stderr で知らせる" grep -q "2 ページ目から先のレビューを読めなかった（TimeoutError）" <<<"$out"

empty=$(python3 -I - "$root" "$scripts/fetch-rival-reviews.py" 2>&1 <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

reviews = load_module(sys.argv[2])
install(lambda method, url, body: {"feed": {"title": {"label": "t"}}} if "/customerreviews/page=" in url else None)
sys.argv = ["fetch-rival-reviews.py", "123"]
try:
    reviews.main()
except SystemExit as error:
    print("exit", error.code)
report_unknown()
EOF
)
check "fetch-rival-reviews: 1 ページ目から entry が無ければ NG で知らせる" grep -q "^NG レビューを 1 件も取れなかった" <<<"$empty"
check "fetch-rival-reviews: 1 ページ目から entry が無ければ終了コード 1" grep -qx "exit 1" <<<"$empty"

expect "NG 使い方" "search-apps: 引数が無ければ NG" python3 -I "$scripts/search-apps.py"
expect "NG 使い方" "search-apps: 数字でない件数は NG" python3 -I "$scripts/search-apps.py" 家計簿 x
expect "NG 検索できなかった" "search-apps: 通信できなければ NG" python3 -I "$scripts/search-apps.py" 家計簿

search_run() {
    python3 -I - "$root" "$scripts/search-apps.py" "$1" 2>&1 <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

search = load_module(sys.argv[2])
scenario = sys.argv[3]
found = [{"trackId": 111, "trackName": "家計  簿", "averageUserRating": 4.25, "userRatingCount": 30, "formattedPrice": "無料"}]
install(lambda method, url, body: {"results": found if "term=%E5%AE%B6%E8%A8%88%E7%B0%BF" in url and scenario == "hit" else []} if url.startswith("https://itunes.apple.com/search?") else None)
sys.argv = ["search-apps.py", "家計簿"]
search.main()
report_unknown()
EOF
}
none=$(search_run miss)
hit=$(search_run hit)
check "search-apps: 見つかったアプリを ID・評価・件数・価格・名前で出す" grep -qx $'111\t4.2\t30\t無料\t家計 簿' <<<"$hit"
check "search-apps: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$hit$none")"
match "search-apps: 0 件なら NG を出す" "$none" "NG 該当するアプリが無い: 家計簿"

finish
