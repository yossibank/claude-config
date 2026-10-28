import datetime
import json
import re
import sys
import urllib.request

JST = datetime.timezone(datetime.timedelta(hours=9))


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def fetch(url):
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.load(response)


def main():
    if len(sys.argv) < 3 or not sys.argv[1].isdigit():
        fail("使い方: ratings.py <アプリの ID> <YYYY-MM>")

    app, month = sys.argv[1], sys.argv[2]
    if not re.fullmatch(r"[0-9]{4}-(0[1-9]|1[0-2])", month):
        fail(f"月は YYYY-MM で書く: {month}")

    try:
        results = fetch(f"https://itunes.apple.com/lookup?id={app}&country=jp")["results"]
    except Exception as error:
        fail(f"評価を読めなかった: {type(error).__name__}")
    if not results:
        fail(f"アプリが見つからない: {app}")

    info = results[0]
    reviews = 0
    low = 0

    for page in range(1, 11):
        url = f"https://itunes.apple.com/jp/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"
        try:
            entries = fetch(url)["feed"].get("entry", [])
        except Exception as error:
            if page == 1:
                fail(f"レビューを読めなかった: {type(error).__name__}")
            print(f"{page} ページ目から先のレビューを読めなかった", file=sys.stderr)
            break
        if isinstance(entries, dict):
            entries = [entries]
        if not entries:
            break
        older = False
        for entry in entries:
            if "im:rating" not in entry:
                continue
            updated = datetime.datetime.fromisoformat(entry["updated"]["label"]).astimezone(JST).strftime("%Y-%m")
            if updated < month:
                older = True
                continue
            if updated == month:
                reviews += 1
                low += int(entry["im:rating"]["label"]) <= 2
        if older:
            break

    name = " ".join(info["trackName"].split())
    print(f"{name}\t{info.get('averageUserRating', 0):.1f}\t{info.get('userRatingCount', 0)}\t{reviews}\t{low}")


if __name__ == "__main__":
    main()
