#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

scripts="$root/skills/store-report/scripts"
export https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9
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
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_module
sales = load_module(sys.argv[2]).summarize(Path(sys.argv[3]).read_text())
print("\n".join("\t".join([app, *values]) for app, values in sales.items()))
EOF
)
check "fetch-sales: 課金をアプリにまとめ、ダウンロードと通貨ごとの収益を数える" \
    test "$summary" = $'111\t10\t300.00 JPY 1.50 USD\n222\t5\t0'

expect "月は YYYY-MM で書く" "write-report: 月の形が違えば NG" python3 -I "$scripts/write-report.py" 2026-13
mkdir -p "$work/none"
CC_APPS_DIR="$work/none" expect "store/app-id.txt を持つアプリが無い" "write-report: アプリが無ければ NG" python3 -I "$scripts/write-report.py" 2026-09

apps="$work/apps"
mkdir -p "$apps/foo/store" "$apps/bar/store"
echo 123 >"$apps/foo/store/app-id.txt"
echo abc >"$apps/bar/store/app-id.txt"
out=$(CC_APPS_DIR="$apps" python3 -I "$scripts/write-report.py" 2026-09)
check "write-report: 通信できなくても表を書く" test -f "$apps/reports/2026-09.md"
check "write-report: 取れなかったものを WARNING にまとめる" grep -qx '> \[!WARNING\]' <<<"$out"
check "write-report: 売上が取れなければ WARNING の行に書く" grep -q "売上とダウンロードは取れなかった（NG 環境変数が無い" <<<"$out"
check "write-report: 評価が取れなければ WARNING の行に書く" grep -q "foo の評価は取れなかった（NG 評価を読めなかった" <<<"$out"
check "write-report: 数字でないアプリの ID は通信せずに NG にする" grep -q "bar の評価は取れなかった（NG アプリの ID は数字で書く: abc）" <<<"$out"
check "write-report: 取れなかった欄は — にする" grep -q '^| foo | — | — | — | — | — | — |$' <<<"$out"

finish
