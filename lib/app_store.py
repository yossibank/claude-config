import json
import urllib.request

REVIEWS = "https://itunes.apple.com/jp/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"
PAGES = 10


class ReviewPageError(Exception):
    def __init__(self, page, cause):
        super().__init__(f"{page}: {cause}")
        self.page = page
        self.cause = cause


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
