import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from store_api import apps_dir, listed_apps  # noqa: E402
from loader import load_module  # noqa: E402
from script_io import Failure, fail, require_month, run_main  # noqa: E402


STAGE_ROWS = [("インプレッション", "impressions"), ("閲覧", "page_views"), ("初回 DL", "downloads")]
RATE_ROWS = [("閲覧 ÷ インプレッション", "page_views", "impressions"), ("初回 DL ÷ 閲覧", "downloads", "page_views")]


def failure_of(error):
    return f"NG {error}" if isinstance(error, Failure) else f"{type(error).__name__}: {error}"


def percent(totals, numerator, denominator):
    return f"{totals[numerator] / totals[denominator] * 100:.1f}%" if totals and totals[denominator] else "—"


def funnel_lines(repo, funnel, charts, out_dir, labels):
    month = funnel["month"]["totals"]
    previous = funnel["previous"]["totals"] if funnel["previous"] else None
    lines = [
        "",
        f"## {repo} の掲載から DL まで",
        "",
        "| 段 | 今月 | 前の月 |",
        "| --- | --- | --- |",
        *[f"| {label} | {month[key]:,} | {f'{previous[key]:,}' if previous else '—'} |" for label, key in STAGE_ROWS],
        *[f"| {label} | {percent(month, a, b)} | {percent(previous, a, b)} |" for label, a, b in RATE_ROWS],
        "",
        "| ソース | インプレッション | 閲覧 | 初回 DL | 閲覧 ÷ インプレッション |",
        "| --- | --- | --- | --- | --- |",
    ]
    sources = sorted(funnel["month"]["sources"].items(), key=lambda item: -item[1]["page_views"])
    for name, totals in sources:
        label = labels.get(name, name)
        lines.append(f"| {label} | {totals['impressions']:,} | {totals['page_views']:,} | {totals['downloads']:,} "
                     f"| {percent(totals, 'page_views', 'impressions')} |")
    lines.append("")
    lines += [f"![{alt}]({os.path.relpath(path, out_dir)})" for alt, path in charts]
    return lines


def store_events(repo_dir, month, fetch_analytics):
    first, last = fetch_analytics.month_range(month)
    command = ["git", "-C", repo_dir, "log", f"--since={first.isoformat()} 00:00", f"--until={last.isoformat()} 23:59",
               "--date=short", "--format=%ad%x09%s", "--", "store/"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return []
    events = []
    for line in reversed(result.stdout.splitlines()):
        day, _, subject = line.partition("\t")
        label = re.sub(r"\s*\(#\d+\)$", "", re.sub(r"^\w+(\(.+?\))?!?:\s*", "", subject))
        events.append({"day": day, "label": label})
    return events


def funnel_data(funnel, labels):
    current = funnel["month"]
    days = list(current["days"])
    sources = sorted(current["sources"].items(), key=lambda item: -item[1]["page_views"])
    return {
        "days": days,
        **{stage: [current["days"][day][stage] for day in days] for _, stage in STAGE_ROWS},
        "previous": funnel["previous"]["totals"] if funnel["previous"] else None,
        "sources": [[labels.get(name, name), value["impressions"], value["page_views"], value["downloads"]]
                    for name, value in sources],
    }


def kept_next_steps(path):
    if not Path(path).exists():
        return []
    match = re.search(r"^## 次の施策\s*$.*?(?=^## |\Z)", Path(path).read_text(encoding="utf-8"), re.M | re.S)
    return ["", *match.group(0).rstrip().splitlines()] if match else []


def previous_html(out_dir, month, fetch_analytics):
    previous = fetch_analytics.previous_month(month)
    return f"{previous}.html" if Path(out_dir, f"{previous}.html").exists() else None


def main():
    month = require_month(sys.argv[1] if len(sys.argv) > 1 else None, "使い方: write-report.py <YYYY-MM>")
    root = apps_dir()
    out_dir = os.environ.get("CC_REPORTS_DIR", os.path.expanduser("~/Applications/AppReport"))

    apps = listed_apps(root)
    if not apps:
        fail(f"store/app-id.txt を持つアプリが無い: {root}")

    fetch_sales = load_module(os.path.join(HERE, "fetch-sales.py"))
    fetch_ratings = load_module(os.path.join(HERE, "fetch-ratings.py"))
    fetch_analytics = load_module(os.path.join(HERE, "fetch-analytics.py"))
    render_charts = load_module(os.path.join(HERE, "render-charts.py"))
    render_report = load_module(os.path.join(HERE, "render-report.py"))
    sales = {}
    notes = []
    sales_ok = True
    try:
        sales, notice = fetch_sales.sales_by_app(month)
    except Exception as error:
        sales_ok = False
        notes.append(f"売上とダウンロードは取れなかった（{failure_of(error)}）")
    else:
        if notice:
            notes.append(f"売上とダウンロードは日ごとのレポートの合計（{notice}）")

    rows = []
    funnels = []
    report_apps = []
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
        entry = {"repo": repo, "downloads": downloads, "proceeds": proceeds, "rating": rating[0],
                 "rating_count": rating[1], "reviews": rating[2], "low": rating[3], "funnel": None,
                 "events": store_events(os.path.join(root, repo), month, fetch_analytics)}
        report_apps.append(entry)
        try:
            funnel, notices = fetch_analytics.funnel(app_id, month)
        except Exception as error:
            notes.append(f"{repo} の掲載の数字は取れなかった（{failure_of(error)}）")
            continue
        notes += [f"{repo}: {notice}" for notice in notices]
        if funnel is not None:
            charts = render_charts.write_charts(funnel, os.path.join(out_dir, month), repo)
            funnels += funnel_lines(repo, funnel, charts, out_dir, render_charts.SOURCES)
            entry["funnel"] = funnel_data(funnel, render_charts.SOURCES)

    lines = [
        f"# {month} のアプリの数字",
        "",
        "アプリごとのダウンロード・収益・評価・レビューである。評価とレビューは日本の App Store のものである。",
        "",
        "| アプリ | ダウンロード | 収益 | 評価 | 評価の数 | 今月のレビュー | 星 2 以下 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
        *rows,
        *funnels,
    ]
    if notes:
        lines += ["", "> [!WARNING]", *[f"> - {note}" for note in notes]]

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{month}.md")
    lines += kept_next_steps(path)
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    report = {"month": month, "generated": date.today().isoformat(), "apps": report_apps, "notes": notes,
              "previous_html": previous_html(out_dir, month, fetch_analytics)}
    Path(out_dir, f"{month}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    html = render_report.write_html(report, out_dir)
    print("\n".join(lines))
    print(f"\nOK {path}")
    print(f"OK {html}")


if __name__ == "__main__":
    run_main(main)
