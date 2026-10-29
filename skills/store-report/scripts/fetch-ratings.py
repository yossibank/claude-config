import os
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ReviewPageError, clean, fetch_json, review_pages  # noqa: E402
from months import MONTH, to_jst  # noqa: E402
from script_io import Failure, fail  # noqa: E402


LOOKUP = "https://itunes.apple.com/lookup"


def ratings(app, month):
    if not app.isdigit():
        raise Failure(f"アプリの ID は数字で書く: {app}")
    try:
        results = fetch_json(f"{LOOKUP}?{urllib.parse.urlencode({'id': app, 'country': 'jp'})}")["results"]
    except Exception as error:
        raise Failure(f"評価を読めなかった: {type(error).__name__}") from error
    if not results:
        raise Failure(f"アプリが見つからない: {app}")

    info = results[0]
    reviews = 0
    low = 0
    notice = ""

    try:
        for entries in review_pages(app):
            older = False
            for entry in entries:
                updated = to_jst(entry["updated"]["label"]).strftime("%Y-%m")
                if updated < month:
                    older = True
                    continue
                if updated == month:
                    reviews += 1
                    low += int(entry["im:rating"]["label"]) <= 2
            if older:
                break
    except ReviewPageError as error:
        if error.page == 1:
            raise Failure(f"レビューを読めなかった: {type(error.cause).__name__}") from error
        notice = f"{error.page} ページ目から先のレビューを読めなかった"

    fields = [
        clean(info["trackName"]),
        f"{info.get('averageUserRating', 0):.1f}",
        str(info.get("userRatingCount", 0)),
        str(reviews),
        str(low),
    ]
    return fields, notice


def main():
    if len(sys.argv) < 3:
        fail("使い方: fetch-ratings.py <アプリの ID> <YYYY-MM>")

    app, month = sys.argv[1], sys.argv[2]
    if not MONTH.fullmatch(month):
        fail(f"月は YYYY-MM で書く: {month}")

    try:
        fields, notice = ratings(app, month)
    except Failure as error:
        fail(str(error))
    if notice:
        print(notice, file=sys.stderr)
    print("\t".join(fields))


if __name__ == "__main__":
    main()
