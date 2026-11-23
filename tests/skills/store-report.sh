#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/http_fake.sh"

scripts="$root/dotclaude/skills/store-report/scripts"
offline
unset ASC_ISSUER_ID ASC_KEY_ID ASC_KEY_PATH ASC_VENDOR_NUMBER

# 分析のレポートの API（依頼・レポート・インスタンス・区切り）を、決まった中身で返す
read -r -d '' ANALYTICS_FAKE_PY <<'PY' || true
import gzip

ENGAGEMENT_TSV = "Date\tApp Apple Identifier\tEvent\tSource Type\tCounts\tUnique Counts\n" \
    "{month}-01\t123\tImpression\tApp Store search\t100\t90\n" \
    "{month}-01\t123\tPage view\tApp Store search\t10\t9\n" \
    "{month}-02\t123\tImpression\tApp Store browse\t50\t40\n" \
    "{month}-02\t123\tPage view\tApp referrer\t5\t5\n" \
    "{month}-02\t123\tTap\tApp Store search\t7\t7\n" \
    "{previous}-30\t123\tImpression\tApp Store search\t40\t40\n" \
    "{previous}-30\t123\tPage view\tApp Store search\t2\t2\n"
DOWNLOADS_TSV = "Date\tApp Apple Identifier\tDownload Type\tSource Type\tCounts\n" \
    "{month}-01\t123\tFirst-time download\tApp Store search\t2\n" \
    "{month}-02\t123\tRedownload\tApp Store search\t3\n" \
    "{month}-02\t123\tFirst-time download\tApp referrer\t1\n"
created = []


def analytics_route(month, previous, existing=True, instances=True, snapshot=True):
    def route(method, url, body):
        if url.startswith("/v1/apps/") and url.endswith("/analyticsReportRequests"):
            data = [{"id": "on", "attributes": {"accessType": "ONGOING"}},
                    {"id": "snap", "attributes": {"accessType": "ONE_TIME_SNAPSHOT"}}] if existing else []
            return {"data": data, "links": {}}
        if method == "POST" and url == "/v1/analyticsReportRequests":
            access = body["data"]["attributes"]["accessType"]
            created.append(access)
            return {"data": {"id": access.lower(), "attributes": {"accessType": access}}}
        if url.startswith("/v1/analyticsReportRequests/") and url.endswith("/reports"):
            request = url.split("/")[3]
            return {"data": [
                {"id": f"eng-{request}", "attributes": {"name": "App Store Discovery and Engagement Standard"}},
                {"id": f"dl-{request}", "attributes": {"name": "App Downloads Standard"}},
            ], "links": {}}
        if url.startswith("/v1/analyticsReports/") and "/instances" in url:
            report = url.split("/")[3]
            ongoing = report.endswith("-on") or report.endswith("-ongoing")
            past = snapshot and (report.endswith("-snap") or report.endswith("-one_time_snapshot"))
            if not instances or not (ongoing or past):
                return {"data": [], "links": {}}
            return {"data": [{"id": f"i-{report}", "attributes": {"processingDate": f"{month}-02"}}], "links": {}}
        if url.startswith("/v1/analyticsReportInstances/") and url.endswith("/segments"):
            instance = url.split("/")[3]
            return {"data": [{"attributes": {"url": f"https://segments.example/{instance}"}}], "links": {}}
        if url.startswith("https://segments.example/i-eng"):
            return gzip.compress(ENGAGEMENT_TSV.format(month=month, previous=previous).encode())
        if url.startswith("https://segments.example/i-dl"):
            return gzip.compress(DOWNLOADS_TSV.format(month=month, previous=previous).encode())
        return None

    return route
PY
export ANALYTICS_FAKE_PY

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
        if isinstance(reports[key], int):
            return (reports[key], "{}")
        return gzip.compress((header + reports[key]).encode())

    install(route)


serve({
    ("DAILY", "2026-11-01"): "app1\t111\t\t2\t0\t1F\tJPY\n",
    ("DAILY", "2026-11-03"): "app1\t111\t\t3\t0\t1F\tJPY\n",
    ("DAILY", "2026-11-04"): "app1\t111\t\t9\t0\t1F\tJPY\n",
})
result, notice = sales.sales_by_app("2026-11", date(2026, 11, 4))
print(f"daily\t{result['111'][0]}\t{notice}")
print("by_day", *sorted(sales.month_totals("2026-11", date(2026, 11, 4))[3]))

serve({("MONTHLY", "2026-10"): "app1\t111\t\t7\t0\t1F\tJPY\n"})
result, notice = sales.sales_by_app("2026-10", date(2026, 11, 4))
print(f"monthly\t{result['111'][0]}\t{notice}")

serve({})
try:
    sales.sales_by_app("2026-11", date(2026, 11, 4))
except Failure as error:
    print(f"none\t{error}")

serve({
    ("MONTHLY", "2026-01"): "app1\t111\t\t2\t0\t1F\tJPY\n",
    ("MONTHLY", "2025-03"): "app1\t111\t\t4\t0\t1F\tJPY\n",
    ("YEARLY", "2024"): "app1\t111\t\t10\t0\t1F\tJPY\n",
})
previous, before = sales.history_by_app("2026-02", date(2026, 2, 20))
print(f"history\t{previous['111']['downloads']}\t{before['111']['downloads']}")

serve({
    ("MONTHLY", "2026-01"): "app1\t111\t\t2\t0\t1F\tJPY\n",
    ("YEARLY", "2025"): "app1\t111\t\t10\t0\t1F\tJPY\n",
    ("YEARLY", "2024"): 410,
    **{("MONTHLY", f"2024-{m:02d}"): 410 for m in range(1, 13)},
})
previous, before = sales.history_by_app("2026-02", date(2026, 2, 20))
print(f"expired\t{previous['111']['downloads']}\t{before['111']['downloads']}")

print("days", *(len(sales.month_days(m, t)) for m, t in [
    ("2026-02", date(2026, 3, 10)),
    ("2026-12", date(2027, 1, 5)),
    ("2026-11", date(2026, 11, 1)),
    ("2026-11", date(2026, 11, 4)),
]))
EOF
)
check "fetch-sales: 月のレポートが無ければ、前の日までの日ごとのレポートを足す" \
    grep -qx $'daily\t5\t月のレポートがまだ無いので、日ごとのレポートを足した。2026-11-03 まで読み、レポートのあった日は 2 日。' <<<"$daily"
check "fetch-sales: 日ごとのレポートのあった日ごとに合計を返す" grep -qx 'by_day 2026-11-01 2026-11-03' <<<"$daily"
check "fetch-sales: 期限の切れた（410）レポートは、無いものとして累計をやめる" grep -qx $'expired\t2\t12' <<<"$daily"
check "fetch-sales: 月のレポートがあれば、それを使って断り書きを付けない" grep -qx $'monthly\t7\tNone' <<<"$daily"
check "fetch-sales: 年のレポートが無い年は月のレポートで埋め、どちらも無い年で累計をやめる" grep -qx $'history\t2\t16' <<<"$daily"
check "fetch-sales: 日ごとのレポートも無ければ NG" grep -qx $'none\t2026-11 のレポートがまだ無い' <<<"$daily"
check "fetch-sales: 日ごとに読む日は、月の初めから前の日まで" grep -qx 'days 28 31 0 3' <<<"$daily"

expect "月は YYYY-MM で書く" "write-report: 月の形が違えば NG" python3 -I "$scripts/write-report.py" 2026-13
mkdir -p "$work/none"
CC_APPS_DIR="$work/none" CC_REPORTS_DIR="$work/none/reports" expect "store/app-id.txt を持つアプリが無い" "write-report: アプリが無ければ NG" python3 -I "$scripts/write-report.py" 2026-09

apps="$work/apps"
make_apps "$apps" foo=123 bar=abc
out=$(CC_APPS_DIR="$apps" CC_REPORTS_DIR="$apps/reports" env -u ASC_ISSUER_ID -u ASC_KEY_ID -u ASC_KEY_PATH -u ASC_VENDOR_NUMBER python3 -I "$scripts/write-report.py" 2026-09)
check "write-report: 通信できなくても表をデータのフォルダに書く" test -f "$apps/reports/.data/2026-09.md"
check "write-report: 取れなかったものを WARNING にまとめる" grep -qx '> \[!WARNING\]' <<<"$out"
check "write-report: 売上が取れなければ WARNING の行に書く" grep -q "売上とダウンロードは取れなかった（NG 環境変数が無い" <<<"$out"
check "write-report: 評価が取れなければ WARNING の行に書く" grep -q "foo の評価は取れなかった（NG 評価を読めなかった" <<<"$out"
check "write-report: 数字でないアプリの ID は通信せずに NG にする" grep -q "bar の評価は取れなかった（NG アプリの ID は数字で書く: abc）" <<<"$out"
check "write-report: 取れなかった欄は — にする" grep -q '^| foo | — | — | — | — | — | — | — | — |$' <<<"$out"

# 公開の境界（URL と応答）だけを差し替えて、表の数字まで通す
ok_apps="$work/ok-apps"
make_apps "$ok_apps" foo=123
fake_report() {
    CC_APPS_DIR="$ok_apps" CC_REPORTS_DIR="$ok_apps/reports" python3 -I - "$root" "$scripts/write-report.py" "$@" 2>&1 <<'EOF'
import gzip
import json
import os
import sys
import urllib.parse
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])
exec(os.environ["ANALYTICS_FAKE_PY"])

analytics = analytics_route("2026-09", "2026-08")
tsv = "SKU\tApple Identifier\tParent Identifier\tUnits\tDeveloper Proceeds\tProduct Type Identifier\tCurrency of Proceeds\n" \
    "app1\t123\t\t7\t0\t1F\tJPY\n" \
    "coin\t901\t123\t2\t150\t1F\tJPY\n"
entry = lambda day, rating: {"updated": {"label": f"2026-09-{day}T00:00:00-07:00"}, "im:rating": {"label": rating}}


def route(method, url, body):
    if url.startswith("/v1/salesReports"):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
        key = (query["filter[frequency]"][0], query["filter[reportDate]"][0])
        head = tsv.split("\n")[0]
        sold = {("MONTHLY", "2026-09"): tsv, ("MONTHLY", "2026-08"): head + "\napp1\t123\t\t3\t0\t1F\tJPY\n",
                ("YEARLY", "2025"): head + "\napp1\t123\t\t10\t0\t1F\tJPY\n"}.get(key)
        return gzip.compress(sold.encode()) if sold else (404, "{}")
    if url.startswith("https://itunes.apple.com/lookup"):
        return {"results": [{"trackName": "Foo", "averageUserRating": 4.5, "userRatingCount": 20}]}
    if url.startswith("https://itunes.apple.com/jp/rss/customerreviews/page=1/"):
        return {"feed": {"entry": [entry("10", "5"), entry("11", "1"), entry("12", "2")]}}
    if url.startswith("https://itunes.apple.com/jp/rss/customerreviews/page=2/"):
        return {"feed": {}}
    return analytics(method, url, body)


module = load_module(sys.argv[2])
install(route)
sys.argv = ["write-report.py", "2026-09"]
module.run_main(module.main)
report_unknown()
EOF
}
out=$(fake_report)
check "write-report: 表の数字を、売上・累計・評価・レビューから出す" grep -qx '| foo | 9 | 300.00 JPY | 22 | 300.00 JPY | 4.5 | 20 | 3 | 2 |' <<<"$out"
check "write-report: 全部取れた時は、届いた日の範囲と数え方のほかに WARNING を出さない" test "$(grep -c '^> - ' <<<"$out")" = 2
check "write-report: 延べの数と画面の違いを WARNING に書く" grep -q '^> - foo: インプレッションと閲覧は延べの数で' <<<"$out"
check "write-report: 初回 DL は売上のレポートの数にする" grep -qx '| 初回 DL | 9 | 3 | 22 |' <<<"$out"
check "write-report: 日ごとの売上のレポートが無ければ、日ごとの初回 DL は分析のレポートのままにする" test "$(jq -c '.apps[0].funnel.downloads' "$ok_apps/reports/.data/2026-09.json")" = "[2,1]"
check "write-report: 月の初回 DL は売上の数を JSON に書く" test "$(jq -c '.apps[0].funnel.totals.downloads' "$ok_apps/reports/.data/2026-09.json")" = 9
check "write-report: 月のレポートで作った終わった月は速報にしない" test "$(jq -r '.provisional' "$ok_apps/reports/.data/2026-09.json")" = false
check "write-report: 速報でない表の題に（速報）を付けない" grep -qx '# 2026-09 のアプリの数字' <<<"$out"
check "write-report: 前の月の売上を JSON に書く" test "$(jq -c '.apps[0].previous_sales' "$ok_apps/reports/.data/2026-09.json")" = '{"downloads":3,"proceeds":"0"}'
check "write-report: 累計の売上を JSON に書く" test "$(jq -c '.apps[0].total_sales' "$ok_apps/reports/.data/2026-09.json")" = '{"downloads":22,"proceeds":"300.00 JPY"}'
check "write-report: 売上の出どころを JSON に書く" test "$(jq -r '.sales_source' "$ok_apps/reports/.data/2026-09.json")" = 月のレポート
check "write-report: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$out")"
check "write-report: 掲載から DL までの段を、今月と前の月で並べる" grep -qx '| インプレッション（延べ） | 150 | 40 | 190 |' <<<"$out"
check "write-report: 段の割合を出す" grep -qx '| 閲覧 ÷ インプレッション | 10.0% | 5.0% | 8.9% |' <<<"$out"
check "write-report: ソース別の行を出す" grep -qx '| App Store の検索 | 100 | 10 | 2 | 10.0% |' <<<"$out"
check "write-report: 表のフォルダには HTML だけを置く" test "$(ls "$ok_apps/reports")" = 2026-09.html
check "write-report: HTML のパスを出す" grep -qx "OK $ok_apps/reports/2026-09.html" <<<"$out"
check "write-report: 累計の数え始めを表に書く" grep -qx '累計は 2026-08-30 から数えた。' <<<"$out"
check "write-report: 累計を JSON に書く" test "$(jq -c '.apps[0].funnel.total.impressions' "$ok_apps/reports/.data/2026-09.json")" = 190
check "write-report: 日ごとの数字を JSON に書く" test "$(jq -c '.apps[0].funnel.impressions' "$ok_apps/reports/.data/2026-09.json")" = "[100,50]"
check "write-report: ソースを日本語の名前で JSON に書く" test "$(jq -r '.apps[0].funnel.sources[0][0]' "$ok_apps/reports/.data/2026-09.json")" = "App Store の検索"
check "write-report: HTML にデータを埋める" test -z "$(grep __REPORT__ "$ok_apps/reports/2026-09.html")"
check "write-report: 通信できなくても HTML を書く" test -f "$apps/reports/2026-09.html"
printf '\n## 次の施策\n\n- ⬜ 画像を差し替える：開いた割合を上げる\n' >>"$ok_apps/reports/.data/2026-09.md"
fake_report >/dev/null
check "write-report: 作り直しても、書き足した次の施策を残す" grep -qx -- '- ⬜ 画像を差し替える：開いた割合を上げる' "$ok_apps/reports/.data/2026-09.md"
check "write-report: 作り直しても、次の施策をページに入れる" grep -q '"title": "画像を差し替える"' "$ok_apps/reports/2026-09.html"
check "write-report: 掲載の数字が無いアプリは funnel を null にする" test "$(jq -r '.apps[0].funnel' "$apps/reports/.data/2026-09.json")" = null

expect "使い方" "render-report: 引数が無ければ NG" python3 -I "$scripts/render-report.py"
CC_REPORTS_DIR="$work/none" expect "write-report.py を走らせる" "render-report: JSON が無ければ NG" python3 -I "$scripts/render-report.py" 2026-09
reports="$work/render"
mkdir -p "$reports/.data"
cat >"$reports/.data/2026-09.json" <<'EOF'
{"month": "2026-09", "generated": "2026-10-01", "notes": ["</script><b>x</b>"], "apps": []}
EOF
cat >"$reports/.data/2026-09.md" <<'EOF'
# 2026-09 のアプリの数字

## 次の施策

- ✅ 画像を差し替える：開いた割合を上げる
- 名前を見直す
EOF
CC_REPORTS_DIR="$reports" python3 -I "$scripts/render-report.py" 2026-09 >/dev/null
html="$reports/2026-09.html"
check "render-report: 次の施策の印・題・中身を読む" grep -q '"status": "✅", "title": "画像を差し替える", "body": "開いた割合を上げる"' "$html"
check "render-report: 印の無い施策は印を空にする" grep -q '"status": "", "title": "名前を見直す", "body": ""' "$html"
check "render-report: データの中の </script> で埋め込みを閉じない" grep -q '<\\/script><b>x<\\/b>' "$html"
legacy="$work/legacy"
mkdir -p "$legacy/2026-08"
echo '{"month": "2026-08", "generated": "2026-09-01", "notes": [], "apps": []}' >"$legacy/2026-08.json"
printf '# 2026-08\n\n## 次の施策\n\n- ⬜ 前の版の施策：残す\n' >"$legacy/2026-08.md"
touch "$legacy/2026-08/foo-funnel-daily.svg"
CC_REPORTS_DIR="$legacy" python3 -I "$scripts/render-report.py" 2026-08 >/dev/null
check "render-report: 前の版の表と JSON を .data/ に移し、SVG のフォルダを消す" test "$(cd "$legacy" && find . -mindepth 1 | sort | tr '\n' ' ')" = "./.data ./.data/2026-08.json ./.data/2026-08.md ./2026-08.html "
check "render-report: 前の版の表に書き足した次の施策をページに入れる" grep -q '"title": "前の版の施策"' "$legacy/2026-08.html"
check "render-report: 前後の月のページが無ければ指さない" grep -q '"previous_html": null, "next_html": null' "$html"
touch "$reports/2026-08.html" "$reports/2026-10.html"
CC_REPORTS_DIR="$reports" python3 -I "$scripts/render-report.py" 2026-09 >/dev/null
check "render-report: 前後の月のページがあれば指す" grep -q '"previous_html": "2026-08.html", "next_html": "2026-10.html"' "$html"

events_repo="$work/events-repo"
git init -q "$events_repo"
mkdir -p "$events_repo/store/screenshots/6.9" "$events_repo/store/ja"
echo a >"$events_repo/store/screenshots/6.9/01.png"
echo a >"$events_repo/store/ja/keywords.txt"
git -C "$events_repo" add store
GIT_AUTHOR_DATE="2026-09-12T10:00:00" GIT_COMMITTER_DATE="2026-09-12T10:00:00" \
    git -C "$events_repo" -c user.name=t -c user.email=t@example.com commit -qm "build: retake the screenshots (#12)"
echo a >"$events_repo/store/ja/support_url.txt"
git -C "$events_repo" add store
GIT_AUTHOR_DATE="2026-09-14T10:00:00" GIT_COMMITTER_DATE="2026-09-14T10:00:00" \
    git -C "$events_repo" -c user.name=t -c user.email=t@example.com commit -qm "build: change the support url"
echo b >"$events_repo/b.txt"
git -C "$events_repo" add b.txt
GIT_AUTHOR_DATE="2026-09-13T10:00:00" GIT_COMMITTER_DATE="2026-09-13T10:00:00" \
    git -C "$events_repo" -c user.name=t -c user.email=t@example.com commit -qm "feat: outside the store"
events=$(python3 -I - "$root" "$scripts" "$events_repo" <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
write_report = load_module(os.path.join(sys.argv[2], "write-report.py"))
fetch_analytics = load_module(os.path.join(sys.argv[2], "fetch-analytics.py"))
print(write_report.store_events(sys.argv[3], "2026-09", fetch_analytics))
print(write_report.store_events(sys.argv[3] + "-none", "2026-09", fetch_analytics))
EOF
)
check "write-report: store/ を変えた日を、変えた掲載の部分の日本語の言葉で出す" grep -qx "\[{'day': '2026-09-12', 'label': 'スクリーンショット・キーワードを変えた'}\]" <<<"$events"
check "write-report: git のリポジトリでなければ掲載を変えた日を出さない" grep -qx '\[\]' <<<"$events"
provisional=$(python3 -I - "$root" "$scripts" <<'EOF'
import os
import sys
from datetime import date
exec(os.environ["PY_PRELUDE"])
write_report = load_module(os.path.join(sys.argv[2], "write-report.py"))
print(*(write_report.is_provisional(m, s, t) for m, s, t in [
    ("2026-10", "月のレポート", date(2026, 11, 1)),
    ("2026-10", "日ごとのレポート 31 日分", date(2026, 11, 1)),
    ("2026-11", "月のレポート", date(2026, 11, 30)),
]))
EOF
)
check "write-report: 月のレポートが無いか、月の途中なら速報にする" test "$provisional" = "False True True"
applied=$(python3 -I - "$root" "$scripts" <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
write_report = load_module(os.path.join(sys.argv[2], "write-report.py"))
stage = lambda downloads: {"impressions": 0, "page_views": 0, "downloads": downloads}
funnel = {"month": {"totals": stage(9), "days": {"2026-11-01": stage(4), "2026-11-02": stage(5), "2026-11-03": stage(6)}},
          "previous": {"totals": stage(7)}, "total": {"totals": stage(20)}}
by_day = {"2026-11-02": {"1": {"downloads": 3}}}
notes = write_report.apply_sales_downloads(funnel, "1", {"1": {"downloads": 3}}, None, None, by_day)
print(*(funnel["month"]["days"][day]["downloads"] for day in sorted(funnel["month"]["days"])), funnel["previous"]["totals"]["downloads"])
print(*notes, sep="\n")
EOF
)
check "write-report: 届いた最後の日までは売上の数にし、無い日は 0、その後の日は分析のレポートのままにする" grep -qx '0 3 6 7' <<<"$applied"
check "write-report: 前の月と累計を差し替えられなければ、延べの数だと知らせる" test "$(grep -c '延べの数である' <<<"$applied")" = 2

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

expect "使い方" "fetch-analytics: 引数が足りなければ NG" python3 -I "$scripts/fetch-analytics.py" 123
expect "環境変数が無い" "fetch-analytics: キーが無ければ NG" env -u ASC_ISSUER_ID -u ASC_KEY_ID -u ASC_KEY_PATH python3 -I "$scripts/fetch-analytics.py" 123 2026-09

asc_keys
analytics_run() {
    python3 -I - "$root" "$scripts/fetch-analytics.py" "$@" 2>&1 <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])
exec(os.environ["ANALYTICS_FAKE_PY"])

analytics = load_module(sys.argv[2])
from datetime import date
install(analytics_route("2026-11", "2026-10", existing=sys.argv[3] == "existing", instances=sys.argv[4] == "instances",
                        snapshot=sys.argv[5] == "snapshot"))
result, notices = analytics.funnel("123", "2026-11", date(2026, 11, int(sys.argv[6])))
print("created", ",".join(created))
print("notices", " / ".join(notices))
if result:
    print("month", *(result["month"]["totals"][key] for key in analytics.STAGES))
    print("previous", *(result["previous"]["totals"][key] for key in analytics.STAGES))
    print("search", *(result["month"]["sources"]["App Store search"][key] for key in analytics.STAGES))
    print("days", ",".join(result["month"]["days"]))
    print("total", *(result["total"]["totals"][key] for key in analytics.STAGES), result["total"]["since"])
else:
    print("none")
report_unknown()
EOF
}
full=$(analytics_run existing instances snapshot 3)
check "fetch-analytics: インプレッション・閲覧・初回 DL を月で足す" grep -qx 'month 150 15 3' <<<"$full"
check "fetch-analytics: 前の月も同じ形で足す" grep -qx 'previous 40 2 0' <<<"$full"
check "fetch-analytics: ソースごとに分ける" grep -qx 'search 100 10 2' <<<"$full"
check "fetch-analytics: 日ごとに分け、月の外の日は入れない" grep -qx 'days 2026-11-01,2026-11-02' <<<"$full"
check "fetch-analytics: 依頼があれば作らない" grep -qx 'created ' <<<"$full"
check "fetch-analytics: 累計は、前の月までの月ごとの分に今月を足し、数え始めの日を出す" grep -qx 'total 190 17 3 2026-10-30' <<<"$full"
check "fetch-analytics: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$full")"
fresh=$(analytics_run missing none snapshot 3)
check "fetch-analytics: 依頼が無ければ、続けて取る依頼と過去の分の依頼を作る" grep -qx 'created ONGOING,ONE_TIME_SNAPSHOT' <<<"$fresh"
check "fetch-analytics: まだレポートが無ければ数字を返さず知らせる" grep -q '^notices .*作った / まだ分析のレポートが無い' <<<"$fresh"
check "fetch-analytics: まだレポートが無ければ None にする" grep -qx 'none' <<<"$fresh"
check "fetch-analytics: 前の日まで届いていて、過去の分もあれば知らせない" grep -qx 'notices ' <<<"$full"
part=$(analytics_run existing instances nosnap 10)
check "fetch-analytics: 届いた日が月の初めから前の日までに足りなければ、日の範囲を知らせる" \
    grep -q '掲載の数字は 2026-11-01〜2026-11-02 の 2 日分だけ。2026-11-01〜2026-11-09 のうち、届いた日を足した。' <<<"$part"
check "fetch-analytics: 過去の分の依頼が届いていなければ知らせる" grep -q '過去の分の依頼（ONE_TIME_SNAPSHOT）の数字は、まだ届いていない' <<<"$part"
check "fetch-analytics: 依頼を作ったばかりなら、過去の分が未着とは知らせない" test -z "$(grep 過去の分の依頼 <<<"$fresh")"

finish
