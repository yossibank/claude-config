import glob
import re
import os
import subprocess
import sys

if len(sys.argv) < 2:
    sys.exit("使い方: report.py <YYYY-MM>")

month = sys.argv[1]
if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", month):
    sys.exit(f"NG 月は YYYY-MM で書く: {month}")
here = os.path.dirname(os.path.abspath(__file__))
apps_dir = os.environ.get("APPS_DIR", os.path.expanduser("~/Applications/AppStore"))
out_dir = os.path.join(apps_dir, "reports")


def run(script, *args):
    result = subprocess.run([sys.executable, "-I", os.path.join(here, script), *args], capture_output=True, text=True)
    message = (result.stderr or result.stdout).strip().splitlines()
    return result.returncode, result.stdout.strip(), message[-1] if message else ""


apps = []
for path in sorted(glob.glob(os.path.join(apps_dir, "*", "store", "app-id.txt"))):
    app_id = open(path, encoding="utf-8").read().strip()
    apps.append((os.path.basename(os.path.dirname(os.path.dirname(path))), app_id))

if not apps:
    sys.exit(f"NG store/app-id.txt を持つアプリが無い: {apps_dir}")

code, out, error = run("sales.py", month)
sales = {}
notes = []
sales_ok = code == 0
if sales_ok:
    for line in out.splitlines():
        app_id, downloads, proceeds = line.split("\t")
        sales[app_id] = (downloads, proceeds)
else:
    notes.append(f"売上とダウンロードは取れなかった（{error}）")

rows = []
for repo, app_id in apps:
    code, out, error = run("ratings.py", app_id, month)
    if code != 0:
        notes.append(f"{repo} の評価は取れなかった（{error}）")
        rating = ["—"] * 4
    else:
        rating = out.split("\t")[1:]
        if error and error != out.splitlines()[-1]:
            notes.append(f"{repo} のレビューは途中までしか数えていない（{error}）")
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
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(lines))
print(f"\nOK {path}")
