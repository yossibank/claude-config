import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from script_io import fail, require_month, run_main  # noqa: E402

TEMPLATE = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "templates", "report.html")
STATUSES = ("✅", "🚧", "⬜")


def reports_dir():
    return os.environ.get("CC_REPORTS_DIR", os.path.expanduser("~/Applications/AppReport"))


def next_steps(markdown):
    match = re.search(r"^## 次の施策\s*$(.*?)(?=^## |\Z)", markdown, re.M | re.S)
    if not match:
        return []
    steps = []
    for line in match.group(1).splitlines():
        item = re.match(r"^\s*[-*]\s+(.*\S)", line)
        if not item:
            continue
        text = item.group(1)
        status = next((mark for mark in STATUSES if text.startswith(mark)), "")
        title, _, body = text[len(status):].strip().partition("：")
        steps.append({"status": status, "title": title.strip(), "body": body.strip()})
    return steps


def render_html(report):
    data = json.dumps(report, ensure_ascii=False).replace("</", "<\\/")
    return Path(TEMPLATE).read_text(encoding="utf-8").replace("__REPORT__", data)


def write_html(report, out_dir):
    month = report["month"]
    markdown = Path(out_dir, f"{month}.md")
    report = {**report, "next": next_steps(markdown.read_text(encoding="utf-8")) if markdown.exists() else []}
    path = os.path.join(out_dir, f"{month}.html")
    Path(path).write_text(render_html(report), encoding="utf-8")
    return path


def main():
    month = require_month(sys.argv[1] if len(sys.argv) > 1 else None, "使い方: render-report.py <YYYY-MM>")
    out_dir = reports_dir()
    source = Path(out_dir, f"{month}.json")
    if not source.exists():
        fail(f"{source} が無い。先に write-report.py を走らせる")
    try:
        report = json.loads(source.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{source} を読めなかった（{error}）")
    else:
        print(f"OK {write_html(report, out_dir)}")


if __name__ == "__main__":
    run_main(main)
