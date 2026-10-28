import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def run(script, *args):
    result = subprocess.run([sys.executable, "-I", os.path.join(HERE, script), *args], capture_output=True, text=True)
    out_lines = result.stdout.strip().splitlines()
    err_lines = result.stderr.strip().splitlines()
    failure = (out_lines or err_lines or [""])[-1] if result.returncode != 0 else ""
    notice = err_lines[-1] if err_lines else ""
    return result.returncode, result.stdout.strip(), failure, notice


def main():
    if len(sys.argv) < 2:
        fail("使い方: write-report.py <YYYY-MM>")

    month = sys.argv[1]
    if not re.fullmatch(r"[0-9]{4}-(0[1-9]|1[0-2])", month):
        fail(f"月は YYYY-MM で書く: {month}")
    apps_dir = os.environ.get("APPS_DIR", os.path.expanduser("~/Applications/AppStore"))
    out_dir = os.path.join(apps_dir, "reports")

    apps = []
    for path in sorted(glob.glob(os.path.join(apps_dir, "*", "store", "app-id.txt"))):
        app_id = open(path, encoding="utf-8").read().strip()
        apps.append((os.path.basename(os.path.dirname(os.path.dirname(path))), app_id))

    if not apps:
        fail(f"store/app-id.txt を持つアプリが無い: {apps_dir}")

    code, out, failure, _ = run("fetch-sales.py", month)
    sales = {}
    notes = []
    sales_ok = code == 0
    if sales_ok:
        for line in out.splitlines():
            app_id, downloads, proceeds = line.split("\t")
            sales[app_id] = (downloads, proceeds)
    else:
        notes.append(f"売上とダウンロードは取れなかった（{failure}）")

    rows = []
    for repo, app_id in apps:
        code, out, failure, notice = run("fetch-ratings.py", app_id, month)
        if code != 0:
            notes.append(f"{repo} の評価は取れなかった（{failure}）")
            rating = ["—"] * 4
        else:
            rating = out.split("\t")[1:]
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
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\nOK {path}")


if __name__ == "__main__":
    main()
