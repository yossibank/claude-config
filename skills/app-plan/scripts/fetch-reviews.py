import json
import sys
import urllib.request

WIDTH = 200


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def clean(text):
    return " ".join(str(text).split())


def main():
    if len(sys.argv) < 2 or not sys.argv[1].isdigit() or (len(sys.argv) > 2 and not sys.argv[2].isdigit()):
        fail("使い方: fetch-reviews.py <アプリの ID> [星の上限]")

    app = sys.argv[1]
    stars = int(sys.argv[2]) if len(sys.argv) > 2 else 2

    for page in range(1, 11):
        url = f"https://itunes.apple.com/jp/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                entries = json.load(response)["feed"].get("entry", [])
        except Exception as error:
            if page == 1:
                fail(f"レビューを読めなかった: {error}")
            break
        if isinstance(entries, dict):
            entries = [entries]
        if not entries:
            break
        for entry in entries:
            if "im:rating" not in entry:
                continue
            rating = int(entry["im:rating"]["label"])
            if rating > stars:
                continue
            print(f"{rating}\t{clean(entry['title']['label'])}\t{clean(entry['content']['label'])[:WIDTH]}")


if __name__ == "__main__":
    main()
