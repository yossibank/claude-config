import json
import os
import re
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from store_api import apps_dir, listed_apps  # noqa: E402
from loader import load_module  # noqa: E402
from script_io import Failure, fail, require_month, run_main  # noqa: E402

render_report = load_module(os.path.join(HERE, "render-report.py"))


STAGE_ROWS = [("インプレッション（延べ）", "impressions"), ("閲覧（延べ）", "page_views"), ("初回 DL", "downloads")]
RATE_ROWS = [("閲覧 ÷ インプレッション", "page_views", "impressions"), ("初回 DL ÷ 閲覧", "downloads", "page_views")]


def failure_of(error):
    return f"NG {error}" if isinstance(error, Failure) else f"{type(error).__name__}: {error}"


def percent(totals, numerator, denominator):
    return f"{totals[numerator] / totals[denominator] * 100:.1f}%" if totals and totals[denominator] else "—"


def funnel_lines(repo, funnel, labels):
    month = funnel["month"]["totals"]
    previous = funnel["previous"]["totals"] if funnel["previous"] else None
    total = funnel["total"]["totals"]
    lines = [
        "",
        f"## {repo} の掲載から DL まで",
        "",
        "| 段 | 今月 | 前の月 | 累計 |",
        "| --- | --- | --- | --- |",
        *[f"| {label} | {month[key]:,} | {f'{previous[key]:,}' if previous else '—'} | {total[key]:,} |" for label, key in STAGE_ROWS],
        *[f"| {label} | {percent(month, a, b)} | {percent(previous, a, b)} | {percent(total, a, b)} |" for label, a, b in RATE_ROWS],
        "",
        f"累計は {funnel['total']['since']} から数えた。",
        "",
        "ソースごとの数は、分析のレポートの延べの数である。初回 DL の合計は、上の表と合わないことがある。",
        "",
        "| ソース | インプレッション | 閲覧 | 初回 DL | 閲覧 ÷ インプレッション |",
        "| --- | --- | --- | --- | --- |",
    ]
    sources = sorted(funnel["month"]["sources"].items(), key=lambda item: -item[1]["page_views"])
    for name, totals in sources:
        label = labels.get(name, name)
        lines.append(f"| {label} | {totals['impressions']:,} | {totals['page_views']:,} | {totals['downloads']:,} "
                     f"| {percent(totals, 'page_views', 'impressions')} |")
    return lines


STORE_PARTS = [
    ("screenshots/", "スクリーンショット"),
    ("name.txt", "名前"),
    ("subtitle.txt", "サブタイトル"),
    ("keywords.txt", "キーワード"),
    ("description.txt", "説明文"),
    ("promotional_text.txt", "宣伝文"),
    ("release_notes.txt", "アップデートの説明"),
    ("custom-pages.json", "カスタムプロダクトページ"),
]


def store_label(paths):
    parts = [label for key, label in STORE_PARTS if any(key in path for path in paths)]
    return f"{'・'.join(parts)}を変えた" if parts else None


def store_events(repo_dir, month, fetch_analytics):
    first, last = fetch_analytics.month_range(month)
    command = ["git", "-C", repo_dir, "log", f"--since={first.isoformat()} 00:00", f"--until={last.isoformat()} 23:59",
               "--date=short", "--format=@@%ad", "--name-only", "--", "store/"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return []
    commits = []
    for line in result.stdout.splitlines():
        if line.startswith("@@"):
            commits.append((line[2:], []))
        elif line.strip() and commits:
            commits[-1][1].append(line.strip())
    events = []
    for day, paths in reversed(commits):
        label = store_label(paths)
        event = {"day": day, "label": label}
        if label and event not in events:
            events.append(event)
    return events


COUNTS_NOTE = "インプレッションと閲覧は延べの数で、画面のユニークデバイスの数とは合わない。初回 DL は売上のレポートの数で、画面と合う。"


def sales_downloads(totals, app_id):
    return totals.get(app_id, {"downloads": 0})["downloads"]


def apply_sales_downloads(funnel, app_id, current, previous, total, by_day):
    """初回 DL を、Apple ID ごとに数える売上のレポートの数に差し替える。差し替えられなければ知らせを返す。"""
    if current is None:
        return "初回 DL は分析のレポートの延べの数（売上のレポートが取れなかった）"
    funnel["month"]["totals"]["downloads"] = sales_downloads(current, app_id)
    if by_day:
        for day, stages in funnel["month"]["days"].items():
            stages["downloads"] = sales_downloads(by_day.get(day, {}), app_id)
    if funnel["previous"] and previous is not None:
        funnel["previous"]["totals"]["downloads"] = sales_downloads(previous, app_id)
    if total is not None:
        funnel["total"]["totals"]["downloads"] = sales_downloads(total, app_id)
    return None


def is_provisional(month, sales_source, today):
    """月のレポートで作っていないか、月がまだ終わっていなければ速報とする。"""
    first = date.fromisoformat(f"{month}-01")
    next_month = (first.replace(day=28) + timedelta(days=4)).replace(day=1)
    return sales_source != "月のレポート" or today < next_month


def funnel_data(funnel, labels):
    current = funnel["month"]
    days = list(current["days"])
    sources = sorted(current["sources"].items(), key=lambda item: -item[1]["page_views"])
    return {
        "days": days,
        **{stage: [current["days"][day][stage] for day in days] for _, stage in STAGE_ROWS},
        "totals": current["totals"],
        "previous": funnel["previous"]["totals"] if funnel["previous"] else None,
        "total": funnel["total"]["totals"],
        "since": funnel["total"]["since"],
        "sources": [[labels.get(name, name), value["impressions"], value["page_views"], value["downloads"]]
                    for name, value in sources],
    }


def kept_next_steps(path):
    if not Path(path).exists():
        return []
    match = re.search(r"^## 次の施策\s*$.*?(?=^## |\Z)", Path(path).read_text(encoding="utf-8"), re.M | re.S)
    return ["", *match.group(0).rstrip().splitlines()] if match else []


def sales_entry(totals, app_id, fetch_sales):
    if totals is None:
        return None
    downloads, proceeds = fetch_sales.formatted(totals.get(app_id, {"downloads": 0, "proceeds": {}}))
    return {"downloads": int(downloads), "proceeds": proceeds}


def main():
    month = require_month(sys.argv[1] if len(sys.argv) > 1 else None, "使い方: write-report.py <YYYY-MM>")
    root = apps_dir()
    out_dir = render_report.reports_dir()
    data_dir = render_report.data_dir(out_dir)
    render_report.move_legacy(out_dir)

    apps = listed_apps(root)
    if not apps:
        fail(f"store/app-id.txt を持つアプリが無い: {root}")

    fetch_sales = load_module(os.path.join(HERE, "fetch-sales.py"))
    fetch_ratings = load_module(os.path.join(HERE, "fetch-ratings.py"))
    fetch_analytics = load_module(os.path.join(HERE, "fetch-analytics.py"))
    current = previous = total = None
    by_day = {}
    notes = []
    sales_source = None
    try:
        current, notice, sales_source, by_day = fetch_sales.month_totals(month)
    except Exception as error:
        notes.append(f"売上とダウンロードは取れなかった（{failure_of(error)}）")
    else:
        if notice:
            notes.append(f"売上とダウンロードは、{notice}")
        try:
            previous, before = fetch_sales.history_by_app(month)
        except Exception as error:
            notes.append(f"前の月と累計の売上は取れなかった（{failure_of(error)}）")
        else:
            total = fetch_sales.added(before, current)

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
        sales = sales_entry(current, app_id, fetch_sales)
        totals = sales_entry(total, app_id, fetch_sales)
        downloads, proceeds = (str(sales["downloads"]), sales["proceeds"]) if sales else ("—", "—")
        total_cells = f"{totals['downloads']} | {totals['proceeds']}" if totals else "— | —"
        rows.append(f"| {repo} | {downloads} | {proceeds} | {total_cells} | {rating[0]} | {rating[1]} | {rating[2]} | {rating[3]} |")
        entry = {"repo": repo, "downloads": downloads, "proceeds": proceeds, "rating": rating[0],
                 "rating_count": rating[1], "reviews": rating[2], "low": rating[3], "funnel": None,
                 "previous_sales": sales_entry(previous, app_id, fetch_sales), "total_sales": totals,
                 "events": store_events(os.path.join(root, repo), month, fetch_analytics)}
        report_apps.append(entry)
        try:
            funnel, notices = fetch_analytics.funnel(app_id, month)
        except Exception as error:
            notes.append(f"{repo} の掲載の数字は取れなかった（{failure_of(error)}）")
            continue
        notes += [f"{repo}: {notice}" for notice in notices]
        if funnel is not None:
            notice = apply_sales_downloads(funnel, app_id, current, previous, total, by_day)
            notes += [f"{repo}: {COUNTS_NOTE}", *([f"{repo}: {notice}"] if notice else [])]
            funnels += funnel_lines(repo, funnel, fetch_analytics.SOURCES)
            entry["funnel"] = funnel_data(funnel, fetch_analytics.SOURCES)

    provisional = is_provisional(month, sales_source, date.today())
    lines = [
        f"# {month} のアプリの数字{'（速報）' if provisional else ''}",
        "",
        *(["速報である。月のレポートが届いたら、作り直して確定させる。", ""] if provisional else []),
        "アプリごとのダウンロード・収益・評価・レビューである。累計は公開からこの月までの合計である。評価とレビューは日本の App Store のものである。",
        "",
        "| アプリ | ダウンロード | 収益 | 累計の DL | 累計の収益 | 評価 | 評価の数 | 今月のレビュー | 星 2 以下 |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
        *rows,
        *funnels,
    ]
    if notes:
        lines += ["", "> [!WARNING]", *[f"> - {note}" for note in notes]]

    os.makedirs(data_dir, exist_ok=True)
    path = os.path.join(data_dir, f"{month}.md")
    lines += kept_next_steps(path)
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    report = {"month": month, "generated": date.today().isoformat(), "apps": report_apps, "notes": notes,
              "sales_source": sales_source, "provisional": provisional}
    Path(data_dir, f"{month}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    html = render_report.write_html(report, out_dir)
    render_report.rerender(out_dir, fetch_analytics.previous_month(month))
    print("\n".join(lines))
    print(f"\nOK {path}")
    print(f"OK {html}")


if __name__ == "__main__":
    run_main(main)
