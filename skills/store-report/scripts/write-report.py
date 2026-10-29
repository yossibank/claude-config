import glob
import os
import sys
from pathlib import Path

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "lib"))

from loader import load_module  # noqa: E402
from script_io import Failure, fail, require_month  # noqa: E402


def failure_of(error):
    return f"NG {error}" if isinstance(error, Failure) else f"{type(error).__name__}: {error}"


def main():
    month = require_month(sys.argv[1] if len(sys.argv) > 1 else None, "使い方: write-report.py <YYYY-MM>")
    apps_dir = os.environ.get("APPS_DIR", os.path.expanduser("~/Applications/AppStore"))
    out_dir = os.path.join(apps_dir, "reports")

    apps = []
    for path in sorted(glob.glob(os.path.join(apps_dir, "*", "store", "app-id.txt"))):
        app_id = Path(path).read_text(encoding="utf-8").strip()
        apps.append((os.path.basename(os.path.dirname(os.path.dirname(path))), app_id))

    if not apps:
        fail(f"store/app-id.txt を持つアプリが無い: {apps_dir}")

    fetch_sales = load_module(os.path.join(HERE, "fetch-sales.py"))
    fetch_ratings = load_module(os.path.join(HERE, "fetch-ratings.py"))
    sales = {}
    notes = []
    sales_ok = True
    try:
        sales = fetch_sales.sales_by_app(month)
    except Exception as error:
        sales_ok = False
        notes.append(f"売上とダウンロードは取れなかった（{failure_of(error)}）")

    rows = []
    for repo, app_id in apps:
        try:
            fields, notice = fetch_ratings.ratings(app_id, month)
        except Exception as error:
            notes.append(f"{repo} の評価は取れなかった（{failure_of(error)}）")
            rating = ["—"] * 4
        else:
            rating = fields[1:]
            if notice:
                notes.append(f"{repo} のレビューは途中までしか数えていない（{notice}）")
        downloads, proceeds = sales.get(app_id, ("0", "0") if sales_ok else ("—", "—"))
        rows.append(f"| {repo} | {downloads} | {proceeds} | {rating[0]} | {rating[1]} | {rating[2]} | {rating[3]} |")

    lines = [
        f"# {month} のアプリの数字",
        "",
        "アプリごとのダウンロード・収益・評価・レビューである。評価とレビューは日本の App Store のものである。",
        "",
        "| アプリ | ダウンロード | 収益 | 評価 | 評価の数 | 今月のレビュー | 星 2 以下 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
        *rows,
    ]
    if notes:
        lines += ["", "> [!WARNING]", *[f"> - {note}" for note in notes]]

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{month}.md")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"\nOK {path}")


if __name__ == "__main__":
    main()
