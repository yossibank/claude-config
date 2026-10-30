import csv
import gzip
import io
import os
import sys
import urllib.error
import urllib.parse
import zlib

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ASC_ERRORS, ASC_KEYS, asc_reason, asc_request, require_keys  # noqa: E402
from script_io import Failure, fail, require_month, run_main  # noqa: E402

DOWNLOADS = {"1", "1F", "1T", "F1"}
KEYS = [*ASC_KEYS, "ASC_VENDOR_NUMBER"]


def fetch_report(month, version):
    query = urllib.parse.urlencode({
        "filter[frequency]": "MONTHLY",
        "filter[reportType]": "SALES",
        "filter[reportSubType]": "SUMMARY",
        "filter[vendorNumber]": os.environ["ASC_VENDOR_NUMBER"],
        "filter[reportDate]": month,
        "filter[version]": version,
    })
    return gzip.decompress(asc_request(f"/v1/salesReports?{query}", "application/a-gzip")).decode("utf-8")


def sales_by_app(month):
    require_keys(KEYS)
    try:
        try:
            text = fetch_report(month, "1_1")
        except urllib.error.HTTPError as error:
            if error.code != 400:
                raise
            text = fetch_report(month, "1_0")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise Failure(f"{month} のレポートがまだ無い") from error
        raise Failure(f"レポートを読めなかった: {error.code}") from error
    except (*ASC_ERRORS, EOFError, zlib.error) as error:
        raise Failure(f"レポートを読めなかった: {asc_reason(error)}") from error
    return summarize(text)


def summarize(text):
    rows = list(csv.DictReader(io.StringIO(text), delimiter="\t"))
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

    for app, (downloads, proceeds) in sales_by_app(month).items():
        print(f"{app}\t{downloads}\t{proceeds}")


if __name__ == "__main__":
    run_main(main)
