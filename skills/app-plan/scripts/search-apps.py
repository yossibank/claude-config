import os
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import clean, fetch_json, reason  # noqa: E402
from script_io import fail  # noqa: E402


def main():
    if len(sys.argv) < 2 or (len(sys.argv) > 2 and not sys.argv[2].isdigit()):
        fail("使い方: search-apps.py <語> [件数]")

    term = sys.argv[1]
    limit = sys.argv[2] if len(sys.argv) > 2 else "10"
    query = urllib.parse.urlencode({"term": term, "country": "jp", "entity": "software", "limit": limit})

    try:
        results = fetch_json(f"https://itunes.apple.com/search?{query}")["results"]
    except Exception as error:
        fail(f"検索できなかった: {reason(error)}")

    for app in results:
        rating = app.get("averageUserRating", 0)
        count = app.get("userRatingCount", 0)
        price = app.get("formattedPrice", "")
        print(f"{app['trackId']}\t{rating:.1f}\t{count}\t{clean(price)}\t{clean(app['trackName'])}")


if __name__ == "__main__":
    main()
