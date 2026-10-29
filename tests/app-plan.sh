#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

scripts="$root/skills/app-plan/scripts"
export https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9

expect "NG 使い方" "fetch-reviews: 引数が無ければ NG" python3 -I "$scripts/fetch-reviews.py"
expect "NG 使い方" "fetch-reviews: 数字でないアプリの ID は NG" python3 -I "$scripts/fetch-reviews.py" abc
expect "NG 使い方" "fetch-reviews: 数字でない星の上限は NG" python3 -I "$scripts/fetch-reviews.py" 123 x
expect "NG レビューを読めなかった" "fetch-reviews: 通信できなければ NG" python3 -I "$scripts/fetch-reviews.py" 123
out=$(python3 -I - "$root" "$scripts/fetch-reviews.py" 2>&1 >/dev/null <<'EOF'
import sys

sys.path.insert(0, f"{sys.argv[1]}/lib")

from app_store import ReviewPageError
from loader import load_module

reviews = load_module(sys.argv[2])


def pages(app):
    yield [{"im:rating": {"label": "1"}, "title": {"label": "t"}, "content": {"label": "c"}}]
    raise ReviewPageError(2, TimeoutError())


reviews.review_pages = pages
sys.argv = ["fetch-reviews.py", "123"]
reviews.main()
EOF
)
check "fetch-reviews: 2 ページ目から先を読めなければ stderr で知らせる" grep -q "2 ページ目から先のレビューを読めなかった（TimeoutError）" <<<"$out"

expect "NG 使い方" "search-apps: 引数が無ければ NG" python3 -I "$scripts/search-apps.py"
expect "NG 使い方" "search-apps: 数字でない件数は NG" python3 -I "$scripts/search-apps.py" 家計簿 x
expect "NG 検索できなかった" "search-apps: 通信できなければ NG" python3 -I "$scripts/search-apps.py" 家計簿

finish
