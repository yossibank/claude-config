import base64
import glob
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path
from subprocess import CalledProcessError, TimeoutExpired

from script_io import Failure

REVIEWS = "https://itunes.apple.com/jp/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"
PAGES = 10
ASC_API = "https://api.appstoreconnect.apple.com"
ASC_KEYS = ["ASC_ISSUER_ID", "ASC_KEY_ID", "ASC_KEY_PATH"]
ASC_ERRORS = (urllib.error.URLError, OSError, CalledProcessError, TimeoutExpired, ValueError)


class ReviewPageError(Exception):
    def __init__(self, page, cause):
        super().__init__(f"{page}: {cause}")
        self.page = page
        self.cause = cause

    @property
    def notice(self):
        return f"{self.page} ページ目から先のレビューを読めなかった（{reason(self.cause)}）"


class EmptyReviewFeed(Exception):
    pass


def reason(error):
    return type(error).__name__


def clean(text):
    return " ".join(str(text).split())


def itunes_json(url, timeout=10):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.load(response)


def paginate(first, fetch, following):
    cursor = first
    while cursor is not None:
        page = fetch(cursor)
        yield page
        cursor = following(cursor, page)


def review_pages(app):
    def fetch(page):
        try:
            feed = itunes_json(REVIEWS.format(page=page, app=app))["feed"]
            entries = feed.get("entry", [])
        except Exception as error:
            raise ReviewPageError(page, error) from error
        if page == 1 and "entry" not in feed:
            raise EmptyReviewFeed()
        return [entries] if isinstance(entries, dict) else entries

    for entries in paginate(1, fetch, lambda page, entries: page + 1 if entries and page < PAGES else None):
        if entries:
            yield [entry for entry in entries if "im:rating" in entry]


def require_app_id(app):
    if not app.isdigit():
        raise Failure(f"アプリの ID は数字で書く: {app}")


def require_keys(keys):
    missing = [key for key in keys if not os.environ.get(key)]
    if missing:
        raise Failure(f"環境変数が無い: {', '.join(missing)}")


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def raw_signature(der):
    def integer(data, at):
        if len(data) < at + 2 or data[at] != 0x02:
            raise ValueError("openssl の署名が DER の整数の形でない")
        length = data[at + 1]
        value = data[at + 2 : at + 2 + length]
        return value.lstrip(b"\0").rjust(32, b"\0"), at + 2 + length

    if len(der) < 2:
        raise ValueError("openssl の署名が空")
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
        timeout=30,
    ).stdout
    return (signing + b"." + b64(raw_signature(der))).decode()


TOKEN_MARGIN = 60
cached_token = {}


def cached(env):
    now = time.time()
    entry = cached_token.get(env)
    if entry is None or entry[1] - TOKEN_MARGIN <= now:
        entry = (token(), now + 1200)
        cached_token[env] = entry
    return entry[0]


def error_detail(body):
    try:
        errors = json.loads(body)["errors"]
        return clean("; ".join(str(item.get("detail") or item.get("title") or "") for item in errors))[:200]
    except (ValueError, KeyError, TypeError, AttributeError):
        return ""


def asc_request(url, accept="application/json", body=None, timeout=30, method=None):
    env = tuple(os.environ.get(key) for key in ASC_KEYS)
    request = urllib.request.Request(
        url if url.startswith("https://") else f"{ASC_API}{url}",
        data=None if body is None else json.dumps(body).encode(),
        method=method or ("GET" if body is None else "POST"),
        headers={
            "Authorization": f"Bearer {cached(env)}",
            "Accept": accept,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        try:
            error.detail = error_detail(error.read())
        except OSError:
            error.detail = ""
        raise


def asc_json(url, body=None, timeout=30, method=None):
    return json.loads(asc_request(url, body=body, timeout=timeout, method=method))


def asc_pages(url):
    yield from paginate(url, asc_json, lambda cursor, page: page.get("links", {}).get("next"))


def asc_reason(error):
    if isinstance(error, urllib.error.HTTPError):
        detail = getattr(error, "detail", "")
        return f"{error.code}: {detail}" if detail else str(error.code)
    return reason(error)


def apps_dir():
    return os.environ.get("CC_APPS_DIR", os.path.expanduser("~/Applications/AppStore"))


def listed_apps(root):
    apps = []
    for path in sorted(glob.glob(os.path.join(root, "*", "store", "app-id.txt"))):
        app_id = Path(path).read_text(encoding="utf-8").strip()
        apps.append((os.path.basename(os.path.dirname(os.path.dirname(path))), app_id))
    return apps


def read_drafts(path):
    try:
        entries = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise Failure(f"返信案のファイルが無い: {path}") from error
    except (OSError, ValueError) as error:
        raise Failure(f"返信案のファイルが JSON として読めない: {path}") from error
    if not isinstance(entries, list) or not all(isinstance(entry, dict) for entry in entries):
        raise Failure(f"返信案のファイルはレビューの配列にする: {path}")
    for number, entry in enumerate(entries, 1):
        if not isinstance(entry.get("id"), str) or not entry["id"]:
            raise Failure(f"返信案の {number} 件目にレビューの id が無い: {path}")
    return entries
