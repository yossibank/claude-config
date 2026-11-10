import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from store_api import ASC_ERRORS, ASC_KEYS, asc_json, asc_pages, asc_reason, asc_request, require_app_id, require_keys  # noqa: E402
from script_io import Failure, fail, run_main, split_dry_run  # noqa: E402

USAGE = "使い方: create-custom-pages.py <アプリのリポジトリ> [--dry-run]"
PROMOTION_LIMIT = 170
PAGE_LIMIT = 200


def read_json(path, label):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise Failure(f"{label}が無い: {path}") from error
    except (OSError, ValueError) as error:
        raise Failure(f"{label}が JSON として読めない: {path}") from error


def read_app(store):
    path = store / "app-id.txt"
    try:
        app = path.read_text(encoding="utf-8").strip()
    except OSError as error:
        raise Failure(f"アプリの ID のファイルが無い: {path}") from error
    require_app_id(app)
    return app


def screenshot_folders(store, plan):
    sets = plan.get("screenshots")
    if not isinstance(sets, dict) or not sets:
        raise Failure("screenshots に、型とフォルダの組を 1 つ以上書く")
    folders = {}
    for kind, folder in sets.items():
        path = store / folder
        files = sorted(item.name for item in path.glob("*.png"))
        if not files:
            raise Failure(f"{kind} のフォルダに PNG が無い: {path}")
        folders[kind] = (path, files)
    return folders


def check_page(page, folders, used, names):
    name = page.get("name")
    if not isinstance(name, str) or not name.strip():
        raise Failure("ページの name が空")
    if name in names:
        raise Failure(f"{name}: 同じ name のページが 2 つある")
    names.add(name)
    keywords = page.get("keywords")
    if not isinstance(keywords, list) or not keywords or not all(isinstance(word, str) for word in keywords):
        raise Failure(f"{name}: keywords に語を 1 つ以上書く")
    shared = sorted(set(keywords) & used)
    if shared:
        raise Failure(f"{name}: ほかのページと語が重なっている: {', '.join(shared)}")
    used.update(keywords)
    promotion = page.get("promotionalText", "")
    if not isinstance(promotion, str) or len(promotion) > PROMOTION_LIMIT:
        raise Failure(f"{name}: promotionalText は {PROMOTION_LIMIT} 字までの文字列にする")
    lead = page.get("lead", [])
    for kind, (path, files) in folders.items():
        missing = [file for file in lead if file not in files]
        if missing:
            raise Failure(f"{name}: {kind} のフォルダに無い画像: {', '.join(missing)}")


def read_plan(repo):
    store = Path(repo) / "store"
    plan = read_json(store / "custom-pages.json", "ページの案のファイル")
    if not isinstance(plan, dict):
        raise Failure("ページの案のファイルは、locale・screenshots・pages を持つオブジェクトにする")
    locale = plan.get("locale")
    if not isinstance(locale, str) or not locale:
        raise Failure("locale を書く")
    pages = plan.get("pages")
    if not isinstance(pages, list) or not pages:
        raise Failure("pages にページを 1 つ以上書く")
    folders = screenshot_folders(store, plan)
    used = set()
    names = set()
    for page in pages:
        if not isinstance(page, dict):
            raise Failure("pages の中身は、ページごとのオブジェクトにする")
        check_page(page, folders, used, names)
    return read_app(store), locale, folders, pages


def ordered(files, lead):
    return lead + [file for file in files if file not in lead]


def all_pages(url):
    return [item for page in asc_pages(url) for item in page.get("data", [])]


def approved_keywords(app, locale):
    versions = asc_json(f"/v1/apps/{app}/appStoreVersions?filter[appStoreState]=READY_FOR_SALE&limit=1")
    if not versions.get("data"):
        raise Failure("配信中の版が無いので、キーワードを選べない")
    version = versions["data"][0]["id"]
    query = urllib.parse.urlencode({"filter[locale]": locale})
    localizations = asc_json(f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations?{query}")
    if not localizations.get("data"):
        raise Failure(f"配信中の版に {locale} の掲載情報が無い")
    localization = localizations["data"][0]["id"]
    return {item["id"] for item in all_pages(f"/v1/appStoreVersionLocalizations/{localization}/searchKeywords?limit={PAGE_LIMIT}")}


def existing_pages(app):
    return {item["attributes"]["name"]: item["id"] for item in all_pages(f"/v1/apps/{app}/appCustomProductPages?limit={PAGE_LIMIT}")}


def page_body(app, locale, page):
    return {
        "data": {
            "type": "appCustomProductPages",
            "attributes": {"name": page["name"]},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app}},
                "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${version}"}]},
            },
        },
        "included": [
            {
                "type": "appCustomProductPageVersions",
                "id": "${version}",
                "relationships": {
                    "appCustomProductPageLocalizations": {
                        "data": [{"type": "appCustomProductPageLocalizations", "id": "${localization}"}]
                    }
                },
            },
            {
                "type": "appCustomProductPageLocalizations",
                "id": "${localization}",
                "attributes": {"locale": locale, "promotionalText": page.get("promotionalText", "")},
            },
        ],
    }


def page_localization(page, locale):
    versions = asc_json(f"/v1/appCustomProductPages/{page}/appCustomProductPageVersions")["data"]
    if not versions:
        raise ValueError("作ったページに版が無い")
    localizations = asc_json(f"/v1/appCustomProductPageVersions/{versions[0]['id']}/appCustomProductPageLocalizations")
    matched = [item["id"] for item in localizations["data"] if item["attributes"]["locale"] == locale]
    if not matched:
        raise ValueError(f"作ったページに {locale} の掲載情報が無い")
    return matched[0]


def add_keywords(localization, keywords):
    body = {"data": [{"type": "appKeywords", "id": word} for word in keywords]}
    asc_request(f"/v1/appCustomProductPageLocalizations/{localization}/relationships/searchKeywords", body=body)


def put_parts(operations, data):
    for operation in operations:
        start = operation["offset"]
        request = urllib.request.Request(
            operation["url"],
            data=data[start : start + operation["length"]],
            method=operation["method"],
            headers={header["name"]: header["value"] for header in operation.get("requestHeaders", [])},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            response.read()


def upload_screenshot(screenshot_set, path):
    data = path.read_bytes()
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": path.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": screenshot_set}}},
        }
    }
    reserved = asc_json("/v1/appScreenshots", body)["data"]
    put_parts(reserved["attributes"]["uploadOperations"], data)
    commit = {
        "data": {
            "type": "appScreenshots",
            "id": reserved["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
        }
    }
    asc_json(f"/v1/appScreenshots/{reserved['id']}", commit, method="PATCH")


def upload_set(localization, kind, path, files):
    body = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": kind},
            "relationships": {
                "appCustomProductPageLocalization": {
                    "data": {"type": "appCustomProductPageLocalizations", "id": localization}
                }
            },
        }
    }
    screenshot_set = asc_json("/v1/appScreenshotSets", body)["data"]["id"]
    for file in files:
        upload_screenshot(screenshot_set, path / file)


def create_page(app, locale, folders, page):
    created = asc_json("/v1/appCustomProductPages", page_body(app, locale, page))["data"]["id"]
    localization = page_localization(created, locale)
    add_keywords(localization, page["keywords"])
    for kind, (path, files) in folders.items():
        upload_set(localization, kind, path, ordered(files, page.get("lead", [])))


def inspect_page(created, locale):
    """ページ側の中身を読む。(途中で止まった理由, キーワードの集合, 画像の組ごとの枚数)"""
    try:
        localization = page_localization(created, locale)
    except ValueError as error:
        return str(error), set(), {}
    keywords = {item["id"] for item in all_pages(f"/v1/appCustomProductPageLocalizations/{localization}/searchKeywords?limit={PAGE_LIMIT}")}
    sets = {
        item["attributes"]["screenshotDisplayType"]: item["id"]
        for item in all_pages(f"/v1/appCustomProductPageLocalizations/{localization}/appScreenshotSets?limit={PAGE_LIMIT}")
    }
    counts = {kind: len(all_pages(f"/v1/appScreenshotSets/{id}/appScreenshots?limit={PAGE_LIMIT}")) for kind, id in sets.items()}
    if not keywords:
        return "キーワードが 1 つも入っていない", keywords, counts
    if not counts:
        return "画像の組が 1 つも無い", keywords, counts
    return "", keywords, counts


def differences(page, folders, keywords, counts):
    found = []
    missing = [word for word in page["keywords"] if word not in keywords]
    if missing:
        found.append(f"手元のキーワードがページに無い: {', '.join(missing)}")
    for kind, (_, files) in folders.items():
        if counts.get(kind) != len(files):
            found.append(f"{kind} の画像がページでは {counts.get(kind, 0)} 枚で、手元は {len(files)} 枚")
    return found


def describe(page, folders):
    sets = "、".join(f"{kind}: {' → '.join(ordered(files, page.get('lead', [])))}" for kind, (_, files) in folders.items())
    return f"{page['name']}（キーワード: {', '.join(page['keywords'])}。{sets}）"


def main():
    args, dry_run = split_dry_run(sys.argv[1:])
    if len(args) != 1:
        fail(USAGE)

    app, locale, folders, pages = read_plan(args[0])

    if dry_run:
        for page in pages:
            print(f"OK 作る予定: {describe(page, folders)}")
        print(f"OK 送らずに {len(pages)} ページの中身を確かめた")
        return

    require_keys(ASC_KEYS)
    try:
        approved = approved_keywords(app, locale)
        existing = existing_pages(app)
    except ASC_ERRORS as error:
        fail(f"App Store Connect を読めなかった: {asc_reason(error)}")
    for page in pages:
        missing = [word for word in page["keywords"] if word not in approved]
        if missing:
            fail(f"{page['name']}: 配信中の版のキーワードに無い語: {', '.join(missing)}")

    for page in pages:
        if page["name"] in existing:
            try:
                problem, keywords, counts = inspect_page(existing[page["name"]], locale)
            except ASC_ERRORS as error:
                fail(f"{page['name']} の中身を読めなかった: {asc_reason(error)}")
            if problem:
                fail(f"{page['name']} は既にあるが、途中で止まったままになっている（{problem}）。App Store Connect で消してから、もう一度実行する")
            for difference in differences(page, folders, keywords, counts):
                print(f"{page['name']}: {difference}。既にあるページは作り直さない", file=sys.stderr)
            print(f"OK {page['name']} は既にあるので作らなかった")
            continue
        try:
            create_page(app, locale, folders, page)
        except Exception as error:
            fail(f"{page['name']} を作る途中で止まった: {asc_reason(error)}。App Store Connect で途中のページを消してから、もう一度実行する")
        print(f"OK {describe(page, folders)} を作った")
    print("OK 審査への提出は、人が App Store Connect で行う")


if __name__ == "__main__":
    run_main(main)
