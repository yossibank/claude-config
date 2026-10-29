import base64
import glob
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path
from subprocess import CalledProcessError

from script_io import Failure

REVIEWS = "https://itunes.apple.com/jp/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"
PAGES = 10
ASC_API = "https://api.appstoreconnect.apple.com"
ASC_KEYS = ["ASC_ISSUER_ID", "ASC_KEY_ID", "ASC_KEY_PATH"]
ASC_ERRORS = (urllib.error.URLError, OSError, CalledProcessError, ValueError)


class ReviewPageError(Exception):
    def __init__(self, page, cause):
        super().__init__(f"{page}: {cause}")
        self.page = page
        self.cause = cause

    @property
    def notice(self):
        return f"{self.page} ページ目から先のレビューを読めなかった（{reason(self.cause)}）"


def reason(error):
    return type(error).__name__


def clean(text):
    return " ".join(str(text).split())


def fetch_json(url, timeout=10):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.load(response)


def review_pages(app):
    for page in range(1, PAGES + 1):
        try:
            entries = fetch_json(REVIEWS.format(page=page, app=app))["feed"].get("entry", [])
        except Exception as error:
            raise ReviewPageError(page, error) from error
        if isinstance(entries, dict):
            entries = [entries]
        if not entries:
            return
        yield [entry for entry in entries if "im:rating" in entry]


def require_keys(keys):
    missing = [key for key in keys if not os.environ.get(key)]
    if missing:
        raise Failure(f"環境変数が無い: {', '.join(missing)}")


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


def asc_json(url, body=None, timeout=30):
    request = urllib.request.Request(
        url if url.startswith("https://") else f"{ASC_API}{url}",
        data=None if body is None else json.dumps(body).encode(),
        method="GET" if body is None else "POST",
        headers={
            "Authorization": f"Bearer {token()}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def asc_reason(error):
    return str(error.code) if isinstance(error, urllib.error.HTTPError) else reason(error)


def apps_dir():
    return os.environ.get("CC_APPS_DIR", os.path.expanduser("~/Applications/AppStore"))


def listed_apps(root):
    apps = []
    for path in sorted(glob.glob(os.path.join(root, "*", "store", "app-id.txt"))):
        app_id = Path(path).read_text(encoding="utf-8").strip()
        apps.append((os.path.basename(os.path.dirname(os.path.dirname(path))), app_id))
    return apps
