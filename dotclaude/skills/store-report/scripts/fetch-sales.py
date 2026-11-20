import csv
import gzip
import io
import os
import sys
import urllib.error
import urllib.parse
import zlib
from datetime import date, timedelta
from decimal import Decimal

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from store_api import ASC_ERRORS, ASC_KEYS, asc_reason, asc_request, require_keys  # noqa: E402
from script_io import Failure, fail, require_month, run_main  # noqa: E402

DOWNLOADS = {"1", "1F", "1T", "F1"}
KEYS = [*ASC_KEYS, "ASC_VENDOR_NUMBER"]
FIRST_YEAR = 2008


def fetch_report(frequency, day, version):
    query = urllib.parse.urlencode({
        "filter[frequency]": frequency,
        "filter[reportType]": "SALES",
        "filter[reportSubType]": "SUMMARY",
        "filter[vendorNumber]": os.environ["ASC_VENDOR_NUMBER"],
        "filter[reportDate]": day,
        "filter[version]": version,
    })
    return gzip.decompress(asc_request(f"/v1/salesReports?{query}", "application/a-gzip")).decode("utf-8")


def fetch_text(frequency, day):
    try:
        return fetch_report(frequency, day, "1_1")
    except urllib.error.HTTPError as error:
        if error.code != 400:
            raise
        return fetch_report(frequency, day, "1_0")


def month_days(month, today):
    first = date.fromisoformat(f"{month}-01")
    next_month = (first.replace(day=28) + timedelta(days=4)).replace(day=1)
    last = min(next_month, today) - timedelta(days=1)
    return [first + timedelta(days=offset) for offset in range((last - first).days + 1)]


def daily_texts(days):
    texts = []
    for day in days:
        try:
            texts.append(fetch_text("DAILY", day.isoformat()))
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
    return texts


def load_texts(month, days):
    try:
        try:
            return [fetch_text("MONTHLY", month)], True
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
        return daily_texts(days), False
    except (*ASC_ERRORS, EOFError, zlib.error) as error:
        raise Failure(f"レポートを読めなかった: {asc_reason(error)}") from error


def month_totals(month, today=None):
    """月の合計と、知らせと、出どころの短い説明を返す。"""
    require_keys(KEYS)
    days = month_days(month, today or date.today())
    texts, monthly = load_texts(month, days)
    if not texts:
        raise Failure(f"{month} のレポートがまだ無い")
    try:
        totals = totals_of(*texts)
    except (KeyError, ValueError, ArithmeticError) as error:
        raise Failure(f"レポートの中身が想定と違う（{type(error).__name__}: {error}）") from error
    if monthly:
        return totals, None, "月のレポート"
    notice = f"月のレポートがまだ無いので、{days[-1].isoformat()} までの日ごとのレポートを足した。レポートのあった日は {len(texts)} 日"
    return totals, notice, f"日ごとのレポート {len(texts)} 日分"


def sales_by_app(month, today=None):
    totals, notice, _ = month_totals(month, today)
    return {app: formatted(total) for app, total in sorted(totals.items())}, notice


def totals_of(*texts):
    rows = [row for text in texts for row in csv.DictReader(io.StringIO(text), delimiter="\t")]
    apps_by_sku = {row["SKU"]: row["Apple Identifier"] for row in rows if not row.get("Parent Identifier", "").strip()}

    totals = {}
    for row in rows:
        parent = row.get("Parent Identifier", "").strip()
        app = apps_by_sku.get(parent, parent) if parent else row["Apple Identifier"]
        units = int(float(row["Units"] or 0))
        proceeds = Decimal(row["Developer Proceeds"] or 0) * units
        total = totals.setdefault(app, {"downloads": 0, "proceeds": {}})
        if row["Product Type Identifier"] in DOWNLOADS:
            total["downloads"] += units
        if proceeds:
            currency = row["Currency of Proceeds"]
            total["proceeds"][currency] = total["proceeds"].get(currency, Decimal(0)) + proceeds
    return totals


def added(*totals_list):
    merged = {}
    for totals in totals_list:
        for app, total in totals.items():
            into = merged.setdefault(app, {"downloads": 0, "proceeds": {}})
            into["downloads"] += total["downloads"]
            for currency, value in total["proceeds"].items():
                into["proceeds"][currency] = into["proceeds"].get(currency, Decimal(0)) + value
    return merged


def formatted(total):
    proceeds = " ".join(f"{value:.2f} {currency}" for currency, value in sorted(total["proceeds"].items())) or "0"
    return str(total["downloads"]), proceeds


def summarize(*texts):
    return {app: formatted(total) for app, total in sorted(totals_of(*texts).items())}


def optional_text(frequency, day):
    try:
        return fetch_text(frequency, day)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        return None


def year_texts(year):
    """年のレポートを返す。まだ無ければ、その年の月のレポートで埋める。どちらも無ければ空にする。"""
    text = optional_text("YEARLY", str(year))
    if text is not None:
        return [text]
    return [text for m in range(1, 13) if (text := optional_text("MONTHLY", f"{year}-{m:02d}")) is not None]


def history_by_app(month, today=None):
    """前の月の合計と、前の月までの累計を返す。月の初めで前の月の月のレポートがまだ無ければ、日ごとのレポートを足す。"""
    require_keys(KEYS)
    today = today or date.today()
    first = date.fromisoformat(f"{month}-01")
    previous = (first - timedelta(days=1)).strftime("%Y-%m")
    try:
        texts = {f"{first.year}-{m:02d}": optional_text("MONTHLY", f"{first.year}-{m:02d}") for m in range(1, first.month)}
        if previous not in texts:
            texts[previous] = optional_text("MONTHLY", previous)
        previous_texts = [texts[previous]] if texts[previous] else []
        if not previous_texts and today < first + timedelta(days=10):
            previous_texts = daily_texts(month_days(previous, today))
        years = []
        year = first.year - 1
        while year >= FIRST_YEAR:
            filled = year_texts(year)
            if not filled:
                break
            years += filled
            year -= 1
    except (*ASC_ERRORS, EOFError, zlib.error) as error:
        raise Failure(f"レポートを読めなかった: {asc_reason(error)}") from error
    try:
        previous_totals = totals_of(*previous_texts)
        months = [totals_of(text) for key, text in texts.items() if text and key != previous and key[:4] == str(first.year)]
        before = added(previous_totals if previous[:4] == str(first.year) else {}, *months, totals_of(*years))
    except (KeyError, ValueError, ArithmeticError) as error:
        raise Failure(f"レポートの中身が想定と違う（{type(error).__name__}: {error}）") from error
    return previous_totals, before


def main():
    usage = "使い方: fetch-sales.py <YYYY-MM>"
    if len(sys.argv) < 2:
        fail(usage)
    require_keys(KEYS)
    month = require_month(sys.argv[1], usage)

    sales, notice = sales_by_app(month)
    for app, (downloads, proceeds) in sales.items():
        print(f"{app}\t{downloads}\t{proceeds}")
    if notice:
        print(notice, file=sys.stderr)


if __name__ == "__main__":
    run_main(main)
