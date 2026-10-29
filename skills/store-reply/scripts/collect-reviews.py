import datetime
import os
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ASC_ERRORS, ASC_KEYS, apps_dir, asc_json, asc_reason, listed_apps, read_drafts, require_keys  # noqa: E402
from dates import JST, to_jst  # noqa: E402
from script_io import Failure, fail, write_json  # noqa: E402

LOW = 2


def reviews_url(app_id):
    query = urllib.parse.urlencode({
        "filter[rating]": ",".join(str(rating) for rating in range(1, LOW + 1)),
        "sort": "-createdDate",
        "limit": 200,
        "include": "response",
    })
    return f"/v1/apps/{app_id}/customerReviews?{query}"


def unanswered(repo, app_id):
    if not app_id.isdigit():
        raise Failure(f"アプリの ID は数字で書く: {app_id}")
    found = []
    url = reviews_url(app_id)
    while url:
        try:
            page = asc_json(url)
        except ASC_ERRORS as error:
            raise Failure(f"レビューを読めなかった: {asc_reason(error)}") from error
        for review in page.get("data", []):
            attributes = review.get("attributes", {})
            response = review.get("relationships", {}).get("response", {}).get("data")
            if response is not None or attributes.get("rating", LOW + 1) > LOW:
                continue
            found.append({
                "app": repo,
                "id": review["id"],
                "rating": attributes["rating"],
                "date": to_jst(attributes["createdDate"]).strftime("%Y-%m-%d"),
                "territory": attributes.get("territory", ""),
                "title": attributes.get("title", ""),
                "body": attributes.get("body", ""),
                "reply": "",
                "approved": False,
            })
        url = page.get("links", {}).get("next")
    return found


def drafts_so_far(path):
    if not os.path.exists(path):
        return {}
    return {entry["id"]: entry for entry in read_drafts(path)}


def main():
    if len(sys.argv) > 1:
        fail("使い方: collect-reviews.py")
    try:
        require_keys(ASC_KEYS)
    except Failure as error:
        fail(str(error))

    root = apps_dir()
    apps = listed_apps(root)
    if not apps:
        fail(f"store/app-id.txt を持つアプリが無い: {root}")
    path = os.path.join(root, "replies", f"{datetime.datetime.now(JST):%Y-%m-%d}.json")
    try:
        kept = drafts_so_far(path)
    except Failure as error:
        fail(str(error))

    found = []
    failed = 0
    for repo, app_id in apps:
        try:
            reviews = unanswered(repo, app_id)
        except Failure as error:
            failed += 1
            print(f"{repo} のレビューは集められなかった（NG {error}）", file=sys.stderr)
            continue
        found += reviews
        print(f"{repo}\t{len(reviews)} 件", file=sys.stderr)
    if failed == len(apps):
        fail("どのアプリのレビューも集められなかった")

    entries = [kept.get(entry["id"], entry) for entry in found]
    write_json(path, entries)
    print(f"OK {path} {len(entries)} 件")


if __name__ == "__main__":
    main()
