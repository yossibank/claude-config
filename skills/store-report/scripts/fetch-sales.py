import csv
import gzip
import io
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ASC_API, ASC_KEYS, require_keys, token  # noqa: E402
from script_io import Failure, fail, require_month  # noqa: E402

DOWNLOADS = {"1", "1F", "1T", "F1"}
KEYS = [*ASC_KEYS, "ASC_VENDOR_NUMBER"]


def report(month, version):
    query = urllib.parse.urlencode({
        "filter[frequency]": "MONTHLY",
        "filter[reportType]": "SALES",
        "filter[reportSubType]": "SUMMARY",
        "filter[vendorNumber]": os.environ["ASC_VENDOR_NUMBER"],
        "filter[reportDate]": month,
        "filter[version]": version,
    })
    request = urllib.request.Request(
        f"{ASC_API}/v1/salesReports?{query}",
        headers={"Authorization": f"Bearer {token()}", "Accept": "application/a-gzip"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return gzip.decompress(response.read()).decode("utf-8")


def sales_by_app(month):
    require_keys(KEYS)
    try:
        try:
            text = report(month, "1_1")
        except urllib.error.HTTPError as error:
            if error.code != 400:
                raise
            text = report(month, "1_0")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise Failure(f"{month} のレポートがまだ無い") from error
        raise Failure(f"レポートを読めなかった: {error.code}") from error
    except (urllib.error.URLError, OSError, subprocess.CalledProcessError) as error:
        raise Failure(f"レポートを読めなかった: {type(error).__name__}") from error
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
    try:
        require_keys(KEYS)
    except Failure as error:
        fail(str(error))
    month = require_month(sys.argv[1], usage)

    try:
        sales = sales_by_app(month)
    except Failure as error:
        fail(str(error))

    for app, (downloads, proceeds) in sales.items():
        print(f"{app}\t{downloads}\t{proceeds}")


if __name__ == "__main__":
    main()
