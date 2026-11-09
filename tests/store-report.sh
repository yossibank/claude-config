#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/http_fake.sh"

scripts="$root/skills/store-report/scripts"
offline
unset ASC_ISSUER_ID ASC_KEY_ID ASC_KEY_PATH ASC_VENDOR_NUMBER

expect "使い方" "fetch-ratings: 引数が足りなければ NG" python3 -I "$scripts/fetch-ratings.py" 123
expect "アプリの ID は数字で書く: abc" "fetch-ratings: 数字でないアプリの ID は NG" python3 -I "$scripts/fetch-ratings.py" abc 2026-09
expect "月は YYYY-MM で書く" "fetch-ratings: 月の形が違えば NG" python3 -I "$scripts/fetch-ratings.py" 123 2026-13
expect "評価を読めなかった" "fetch-ratings: 通信できなければ NG" python3 -I "$scripts/fetch-ratings.py" 123 2026-09

expect "使い方" "fetch-sales: 引数が無ければ NG" python3 -I "$scripts/fetch-sales.py"
expect "環境変数が無い" "fetch-sales: キーが無ければ、月の形より先にキーの NG を出す" python3 -I "$scripts/fetch-sales.py" 2026-13
ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH=z ASC_VENDOR_NUMBER=1 \
    expect "月は YYYY-MM で書く" "fetch-sales: キーがあれば月の形を確かめる" python3 -I "$scripts/fetch-sales.py" 2026-13

{
    printf 'SKU\tApple Identifier\tParent Identifier\tUnits\tDeveloper Proceeds\tProduct Type Identifier\tCurrency of Proceeds\n'
    printf 'app1\t111\t\t10\t0\t1F\tJPY\n'
    printf 'app1\t111\t\t2\t0\t7F\tJPY\n'
    printf 'coin\t901\tapp1\t3\t100\tIA1\tJPY\n'
    printf 'coin\t901\tapp1\t1\t1.5\tIA1\tUSD\n'
    printf 'app2\t222\t\t5\t0\t1\tJPY\n'
} >"$work/sales.tsv"
summary=$(python3 -I - "$root" "$scripts/fetch-sales.py" "$work/sales.tsv" <<'EOF'
import sys
from pathlib import Path
import os
exec(os.environ["PY_PRELUDE"])
sales = load_module(sys.argv[2]).summarize(Path(sys.argv[3]).read_text())
print("\n".join("\t".join([app, *values]) for app, values in sales.items()))
EOF
)
check "fetch-sales: 課金をアプリにまとめ、ダウンロードと通貨ごとの収益を数える" \
    test "$summary" = $'111\t10\t300.00 JPY 1.50 USD\n222\t5\t0'

asc_keys
export ASC_VENDOR_NUMBER=1
daily=$(python3 -I - "$root" "$scripts/fetch-sales.py" <<'EOF'
import gzip
import os
import sys
import urllib.parse
from datetime import date
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])
from script_io import Failure

sales = load_module(sys.argv[2])
header = "SKU\tApple Identifier\tParent Identifier\tUnits\tDeveloper Proceeds\tProduct Type Identifier\tCurrency of Proceeds\n"


def serve(reports):
    def route(method, url, body):
        if not url.startswith("/v1/salesReports?"):
            return None
        query = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
        key = (query["filter[frequency]"][0], query["filter[reportDate]"][0])
        if key not in reports:
            return (404, "{}")
        return gzip.compress((header + reports[key]).encode())

    install(route)


serve({
    ("DAILY", "2026-11-01"): "app1\t111\t\t2\t0\t1F\tJPY\n",
    ("DAILY", "2026-11-03"): "app1\t111\t\t3\t0\t1F\tJPY\n",
    ("DAILY", "2026-11-04"): "app1\t111\t\t9\t0\t1F\tJPY\n",
})
result, notice = sales.sales_by_app("2026-11", date(2026, 11, 4))
print(f"daily\t{result['111'][0]}\t{notice}")

serve({("MONTHLY", "2026-10"): "app1\t111\t\t7\t0\t1F\tJPY\n"})
result, notice = sales.sales_by_app("2026-10", date(2026, 11, 4))
print(f"monthly\t{result['111'][0]}\t{notice}")

serve({})
try:
    sales.sales_by_app("2026-11", date(2026, 11, 4))
except Failure as error:
    print(f"none\t{error}")

print("days", *(len(sales.month_days(m, t)) for m, t in [
    ("2026-02", date(2026, 3, 10)),
    ("2026-12", date(2027, 1, 5)),
    ("2026-11", date(2026, 11, 1)),
    ("2026-11", date(2026, 11, 4)),
]))
EOF
)
check "fetch-sales: 月のレポートが無ければ、前の日までの日ごとのレポートを足す" \
    grep -qx $'daily\t5\t月のレポートがまだ無いので、2026-11-03 までの日ごとのレポートを足した。レポートのあった日は 2 日' <<<"$daily"
check "fetch-sales: 月のレポートがあれば、それを使って断り書きを付けない" grep -qx $'monthly\t7\tNone' <<<"$daily"
check "fetch-sales: 日ごとのレポートも無ければ NG" grep -qx $'none\t2026-11 のレポートがまだ無い' <<<"$daily"
check "fetch-sales: 日ごとに読む日は、月の初めから前の日まで" grep -qx 'days 28 31 0 3' <<<"$daily"

expect "月は YYYY-MM で書く" "write-report: 月の形が違えば NG" python3 -I "$scripts/write-report.py" 2026-13
mkdir -p "$work/none"
CC_APPS_DIR="$work/none" CC_REPORTS_DIR="$work/none/reports" expect "store/app-id.txt を持つアプリが無い" "write-report: アプリが無ければ NG" python3 -I "$scripts/write-report.py" 2026-09

apps="$work/apps"
make_apps "$apps" foo=123 bar=abc
out=$(CC_APPS_DIR="$apps" CC_REPORTS_DIR="$apps/reports" env -u ASC_ISSUER_ID -u ASC_KEY_ID -u ASC_KEY_PATH -u ASC_VENDOR_NUMBER python3 -I "$scripts/write-report.py" 2026-09)
check "write-report: 通信できなくても表を書く" test -f "$apps/reports/2026-09.md"
check "write-report: 取れなかったものを WARNING にまとめる" grep -qx '> \[!WARNING\]' <<<"$out"
check "write-report: 売上が取れなければ WARNING の行に書く" grep -q "売上とダウンロードは取れなかった（NG 環境変数が無い" <<<"$out"
check "write-report: 評価が取れなければ WARNING の行に書く" grep -q "foo の評価は取れなかった（NG 評価を読めなかった" <<<"$out"
check "write-report: 数字でないアプリの ID は通信せずに NG にする" grep -q "bar の評価は取れなかった（NG アプリの ID は数字で書く: abc）" <<<"$out"
check "write-report: 取れなかった欄は — にする" grep -q '^| foo | — | — | — | — | — | — |$' <<<"$out"

# 公開の境界（URL と応答）だけを差し替えて、表の数字まで通す
ok_apps="$work/ok-apps"
make_apps "$ok_apps" foo=123
fake_report() {
    CC_APPS_DIR="$ok_apps" CC_REPORTS_DIR="$ok_apps/reports" python3 -I - "$root" "$scripts/write-report.py" "$@" 2>&1 <<'EOF'
import gzip
import json
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

tsv = "SKU\tApple Identifier\tParent Identifier\tUnits\tDeveloper Proceeds\tProduct Type Identifier\tCurrency of Proceeds\n" \
    "app1\t123\t\t7\t0\t1F\tJPY\n" \
    "coin\t901\t123\t2\t150\t1F\tJPY\n"
entry = lambda day, rating: {"updated": {"label": f"2026-09-{day}T00:00:00-07:00"}, "im:rating": {"label": rating}}


def route(method, url, body):
    if url.startswith("/v1/salesReports"):
        return gzip.compress(tsv.encode())
    if url.startswith("https://itunes.apple.com/lookup"):
        return {"results": [{"trackName": "Foo", "averageUserRating": 4.5, "userRatingCount": 20}]}
    if url.startswith("https://itunes.apple.com/jp/rss/customerreviews/page=1/"):
        return {"feed": {"entry": [entry("10", "5"), entry("11", "1"), entry("12", "2")]}}
    if url.startswith("https://itunes.apple.com/jp/rss/customerreviews/page=2/"):
        return {"feed": {}}
    return None


module = load_module(sys.argv[2])
install(route)
sys.argv = ["write-report.py", "2026-09"]
module.run_main(module.main)
report_unknown()
EOF
}
out=$(fake_report)
check "write-report: 表の数字を、売上・評価・レビューから出す" grep -qx '| foo | 9 | 300.00 JPY | 4.5 | 20 | 3 | 2 |' <<<"$out"
check "write-report: 全部取れた時は WARNING を出さない" test -z "$(grep WARNING <<<"$out")"
check "write-report: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$out")"

checked=$(python3 -I - "$root" "$scripts/fetch-sales.py" <<'EOF'
import gzip
import os
import sys
from datetime import date
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])
from script_io import Failure

sales = load_module(sys.argv[2])
header = "SKU\tApple Identifier\tParent Identifier\tUnits\tDeveloper Proceeds\tProduct Type Identifier\tCurrency of Proceeds\n"
install(lambda method, url, body: gzip.compress((header + "app1\t111\t\t1\t2.675\t1F\tUSD\n").encode()))
print("decimal", sales.sales_by_app("2026-10", date(2026, 11, 4))[0]["111"][1])
install(lambda method, url, body: gzip.compress((header + "app1\t111\t\tx\t0\t1F\tUSD\n").encode()))
try:
    sales.sales_by_app("2026-10", date(2026, 11, 4))
except Failure as error:
    print("broken", error)
EOF
)
check "fetch-sales: 金額を Decimal で足す" grep -qx 'decimal 2.68 USD' <<<"$checked"
check "fetch-sales: 中身が想定と違う時は、読めなかったではなく中身の NG にする" grep -q '^broken レポートの中身が想定と違う（ValueError' <<<"$checked"

ratings_run() {
    python3 -I - "$root" "$scripts/fetch-ratings.py" "$1" 2>&1 <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

ratings = load_module(sys.argv[2])
rows = {
    "old": [{"updated": {"label": "2026-09-05T00:00:00-07:00"}, "im:rating": {"label": "1"}}],
    "all": [{"updated": {"label": "2026-10-05T00:00:00-07:00"}, "im:rating": {"label": "1"}}],
    "empty": [],
}[sys.argv[3]]


def route(method, url, body):
    if url.startswith("https://itunes.apple.com/lookup"):
        return {"results": [{"trackName": "A", "averageUserRating": 3.5, "userRatingCount": 8}]}
    if "/customerreviews/page=" in url:
        return {"feed": {"entry": rows} if rows else {"title": {"label": "t"}}}
    return None


install(route)
fields, notice = ratings.ratings("123", "2026-10")
print("|".join(fields))
print(notice)
report_unknown()
EOF
}
pages=$(ratings_run all)
check "fetch-ratings: 10 ページ読み切っても月の終わりに届かなければ知らせる" grep -q '10 ページ（上限）までしか読めない' <<<"$pages"

done_run=$(ratings_run old)
check "fetch-ratings: 取れた時は名前・評価・評価の数・今月のレビュー・星 2 以下を出す" grep -qx 'A|3.5|8|0|0' <<<"$done_run"
check "fetch-ratings: 月より古いレビューで読むのをやめる" grep -qx '' <<<"$(sed -n 2p <<<"$done_run")"
empty_run=$(ratings_run empty)
check "fetch-ratings: 1 ページ目から entry が無ければ、レビューの数を 0 にせず — にする" grep -qx 'A|3.5|8|—|—' <<<"$empty_run"
check "fetch-ratings: 1 ページ目から entry が無ければ知らせる" grep -q 'レビューの RSS が 1 ページ目から空だった' <<<"$empty_run"
check "fetch-ratings: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$pages$done_run$empty_run")"

finish
