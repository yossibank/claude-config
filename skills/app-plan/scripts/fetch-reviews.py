import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ReviewPageError, clean, reason, review_pages  # noqa: E402
from script_io import fail  # noqa: E402

WIDTH = 200


def main():
    if len(sys.argv) < 2 or not sys.argv[1].isdigit() or (len(sys.argv) > 2 and not sys.argv[2].isdigit()):
        fail("使い方: fetch-reviews.py <アプリの ID> [星の上限]")

    app = sys.argv[1]
    stars = int(sys.argv[2]) if len(sys.argv) > 2 else 2

    try:
        for entries in review_pages(app):
            for entry in entries:
                rating = int(entry["im:rating"]["label"])
                if rating > stars:
                    continue
                print(f"{rating}\t{clean(entry['title']['label'])}\t{clean(entry['content']['label'])[:WIDTH]}")
    except ReviewPageError as error:
        if error.page == 1:
            fail(f"レビューを読めなかった: {reason(error.cause)}")
        print(error.notice, file=sys.stderr)


if __name__ == "__main__":
    main()
