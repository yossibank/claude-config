import base64
import csv
import gzip
import io
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from months import MONTH  # noqa: E402
from script_io import Failure, fail  # noqa: E402

DOWNLOADS = {"1", "1F", "1T", "F1"}
KEYS = ["ASC_ISSUER_ID", "ASC_KEY_ID", "ASC_KEY_PATH", "ASC_VENDOR_NUMBER"]


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def raw_signature(der):
    def integer(data, at):
        assert data[at] == 0x02
        length = data[at + 1]
        value = data[at + 2 : at + 2 + length]
        return value.lstrip(b"\0").rjust(32, b"\0"), at + 2 + length

    at = 2 if der[1] < 0x80 else 3
    r, at = integer(der, at)
    s, _ = integer(der, at)
    return r + s


def token():
    now = int(time.time())
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing = b64(json.dumps(header).encode()) + b"." + b64(json.dumps(payload).encode())
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", os.environ["ASC_KEY_PATH"]],
        input=signing,
        capture_output=True,
        check=True,
    ).stdout
    return (signing + b"." + b64(raw_signature(der))).decode()


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
        f"https://api.appstoreconnect.apple.com/v1/salesReports?{query}",
        headers={"Authorization": f"Bearer {token()}", "Accept": "application/a-gzip"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return gzip.decompress(response.read()).decode("utf-8")


def check_keys():
    missing = [key for key in KEYS if not os.environ.get(key)]
    if missing:
        raise Failure(f"環境変数が無い: {', '.join(missing)}")


def sales_by_app(month):
    check_keys()
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
    if len(sys.argv) < 2:
        fail("使い方: fetch-sales.py <YYYY-MM>")

    month = sys.argv[1]
    try:
        check_keys()
        if not MONTH.fullmatch(month):
            raise Failure(f"月は YYYY-MM で書く: {month}")
        sales = sales_by_app(month)
    except Failure as error:
        fail(str(error))

    for app, (downloads, proceeds) in sales.items():
        print(f"{app}\t{downloads}\t{proceeds}")


if __name__ == "__main__":
    main()
