import base64
import csv
import gzip
import io
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

DOWNLOADS = {"1", "1F", "1T", "F1"}
KEYS = ["ASC_ISSUER_ID", "ASC_KEY_ID", "ASC_KEY_PATH", "ASC_VENDOR_NUMBER"]

if len(sys.argv) < 2:
    sys.exit("使い方: sales.py <YYYY-MM>")

missing = [key for key in KEYS if not os.environ.get(key)]
if missing:
    sys.exit(f"NG 環境変数が無い: {', '.join(missing)}")

month = sys.argv[1]


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


def report(version):
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


try:
    try:
        text = report("1_1")
    except urllib.error.HTTPError as error:
        if error.code != 400:
            raise
        text = report("1_0")
except urllib.error.HTTPError as error:
    if error.code == 404:
        sys.exit(f"NG {month} のレポートがまだ無い")
    sys.exit(f"NG レポートを読めなかった: {error.code}")
except (urllib.error.URLError, OSError, subprocess.CalledProcessError) as error:
    sys.exit(f"NG レポートを読めなかった: {type(error).__name__}")

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

for app, total in sorted(totals.items()):
    proceeds = " ".join(f"{value:.2f} {currency}" for currency, value in sorted(total["proceeds"].items())) or "0"
    print(f"{app}\t{total['downloads']}\t{proceeds}")
