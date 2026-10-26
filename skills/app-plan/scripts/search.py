import json
import sys
import urllib.parse
import urllib.request

if len(sys.argv) < 2 or (len(sys.argv) > 2 and not sys.argv[2].isdigit()):
    sys.exit("使い方: search.py <語> [件数]")

term = sys.argv[1]
limit = sys.argv[2] if len(sys.argv) > 2 else "10"
query = urllib.parse.urlencode({"term": term, "country": "jp", "entity": "software", "limit": limit})

try:
    with urllib.request.urlopen(f"https://itunes.apple.com/search?{query}", timeout=10) as response:
        results = json.load(response)["results"]
except Exception as error:
    sys.exit(f"NG 検索できなかった: {error}")


def clean(text):
    return " ".join(str(text).split())


for app in results:
    rating = app.get("averageUserRating", 0)
    count = app.get("userRatingCount", 0)
    price = app.get("formattedPrice", "")
    print(f"{app['trackId']}\t{rating:.1f}\t{count}\t{clean(price)}\t{clean(app['trackName'])}")
