import csv
import gzip
import io
import os
import sys
import urllib.error
import urllib.parse
import zlib
from datetime import date, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ASC_ERRORS, ASC_KEYS, asc_reason, asc_request, require_keys  # noqa: E402
from script_io import Failure, fail, require_month, run_main  # noqa: E402

DOWNLOADS = {"1", "1F", "1T", "F1"}
KEYS = [*ASC_KEYS, "ASC_VENDOR_NUMBER"]


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


def sales_by_app(month, today=None):
    require_keys(KEYS)
    days = month_days(month, today or date.today())
    try:
        try:
            return summarize(fetch_text("MONTHLY", month)), None
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
        texts = daily_texts(days)
    except urllib.error.HTTPError as error:
        raise Failure(f"レポートを読めなかった: {error.code}") from error
    except (*ASC_ERRORS, EOFError, zlib.error) as error:
        raise Failure(f"レポートを読めなかった: {asc_reason(error)}") from error
    if not texts:
        raise Failure(f"{month} のレポートがまだ無い")
    notice = f"月のレポートがまだ無いので、{days[-1].isoformat()} までの日ごとのレポートを足した。レポートのあった日は {len(texts)} 日"
    return summarize(*texts), notice


def summarize(*texts):
    rows = [row for text in texts for row in csv.DictReader(io.StringIO(text), delimiter="\t")]
    apps_by_sku = {row["SKU"]: row["Apple Identifier"] for row in rows if not row.get("Parent Identifier", "").strip()}

    totals = {}
    for row in rows:
        parent = row.get("Parent Identifier", "").strip()
        app = apps_by_sku.get(parent, parent) if parent else row["Apple Identifier"]
        units = int(float(row["Units"] or 0))
        proceeds = float(row["Developer Proceeds"] or 0) * units
        total = totals.setdefault(app, {"downloads": 0, "proceeds": {}})
        if row["Product Type Identifier"] in DOWNLOADS:
            total["downloads"] += units
        if proceeds:
            currency = row["Currency of Proceeds"]
            total["proceeds"][currency] = total["proceeds"].get(currency, 0) + proceeds

    sales = {}
    for app, total in sorted(totals.items()):
        proceeds = " ".join(f"{value:.2f} {currency}" for currency, value in sorted(total["proceeds"].items())) or "0"
        sales[app] = (str(total["downloads"]), proceeds)
    return sales


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
