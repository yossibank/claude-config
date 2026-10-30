import os
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ReviewPageError, clean, itunes_json, reason, review_pages  # noqa: E402
from dates import month_of  # noqa: E402
from script_io import Failure, fail, require_month  # noqa: E402


LOOKUP = "https://itunes.apple.com/lookup"


def ratings(app, month):
    if not app.isdigit():
        raise Failure(f"アプリの ID は数字で書く: {app}")
    try:
        results = itunes_json(f"{LOOKUP}?{urllib.parse.urlencode({'id': app, 'country': 'jp'})}")["results"]
    except Exception as error:
        raise Failure(f"評価を読めなかった: {reason(error)}") from error
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
                updated = month_of(entry["updated"]["label"])
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
            raise Failure(f"レビューを読めなかった: {reason(error.cause)}") from error
        notice = error.notice

    fields = [
        clean(info["trackName"]),
        f"{info.get('averageUserRating', 0):.1f}",
        str(info.get("userRatingCount", 0)),
        str(reviews),
        str(low),
    ]
    return fields, notice


def main():
    usage = "使い方: fetch-ratings.py <アプリの ID> <YYYY-MM>"
    if len(sys.argv) < 3:
        fail(usage)

    app, month = sys.argv[1], require_month(sys.argv[2], usage)

    try:
        fields, notice = ratings(app, month)
    except Failure as error:
        fail(str(error))
    if notice:
        print(notice, file=sys.stderr)
    print("\t".join(fields))


if __name__ == "__main__":
    main()
