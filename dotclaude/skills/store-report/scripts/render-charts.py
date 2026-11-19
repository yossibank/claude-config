import json
import math
import os
import sys
from html import escape
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from script_io import Failure, fail, run_main  # noqa: E402

WIDTH = 720
HEIGHT = 280
LEFT = 64
RIGHT = 112
TOP = 64
BOTTOM = 36
FONT = "-apple-system, 'Hiragino Sans', 'Helvetica Neue', sans-serif"
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
AXIS = "#c3c2b7"
SERIES = ["#2a78d6", "#eb6834"]
SOURCES = {
    "App Store search": "App Store の検索",
    "App Store browse": "App Store の閲覧",
    "App referrer": "参照元アプリ",
    "Web referrer": "参照元ウェブ",
    "Institutional purchase": "法人購買",
    "Unavailable": "参照元なし",
}


def nice(value):
    if value <= 0:
        return 1
    magnitude = 10 ** math.floor(math.log10(value))
    return next(step * magnitude for step in (1, 2, 2.5, 5, 10) if step * magnitude >= value)


def number(value, percent):
    return f"{value:.1f}%" if percent else f"{value:,.0f}"


def tick(value, percent):
    return f"{value:g}%" if percent else f"{value:,.0f}"


def frame(title, body, height=HEIGHT):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{height}" viewBox="0 0 {WIDTH} {height}" '
        f'font-family="{escape(FONT)}">\n'
        f'<rect width="{WIDTH}" height="{height}" rx="8" fill="{SURFACE}"/>\n'
        f'<text x="24" y="30" font-size="15" font-weight="600" fill="{INK}">{escape(title)}</text>\n'
        f"{body}</svg>\n"
    )


def line_chart(title, days, series, percent=False):
    values = [value for _, points in series for value in points.values() if value is not None]
    top = nice(max(values, default=0))
    plot_w = WIDTH - LEFT - RIGHT
    plot_h = HEIGHT - TOP - BOTTOM
    step = plot_w / max(len(days) - 1, 1)

    def x(index):
        return LEFT + index * step

    def y(value):
        return TOP + plot_h - value / top * plot_h

    parts = []
    for index in range(5):
        value = top * index / 4
        parts.append(f'<line x1="{LEFT}" x2="{LEFT + plot_w}" y1="{y(value):.1f}" y2="{y(value):.1f}" '
                     f'stroke="{AXIS if index == 0 else GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{LEFT - 8}" y="{y(value) + 4:.1f}" font-size="11" fill="{MUTED}" '
                     f'text-anchor="end">{tick(value, percent)}</text>')
    every = max(1, math.ceil(len(days) / 8))
    for index, day in enumerate(days):
        if index % every == 0 or index == len(days) - 1:
            parts.append(f'<text x="{x(index):.1f}" y="{HEIGHT - BOTTOM + 18}" font-size="11" fill="{MUTED}" '
                         f'text-anchor="middle">{int(day[-2:])}日</text>')
    if len(series) > 1:
        legend_x = 24
        for (label, points), color in zip(series, SERIES):
            parts.append(f'<line x1="{legend_x}" x2="{legend_x + 16}" y1="47" y2="47" stroke="{color}" '
                         f'stroke-width="2" stroke-linecap="round"/>')
            parts.append(f'<text x="{legend_x + 22}" y="51" font-size="12" fill="{INK_2}">{escape(label)}</text>')
            legend_x += 34 + 13 * len(label)
    label_ys = []
    for (label, points), color in zip(series, SERIES):
        path = []
        last = None
        for index, day in enumerate(days):
            value = points.get(day)
            if value is None:
                continue
            command = "M" if last is None or last != index - 1 else "L"
            path.append(f"{command}{x(index):.1f},{y(value):.1f}")
            parts.append(f'<circle cx="{x(index):.1f}" cy="{y(value):.1f}" r="8" fill="transparent">'
                         f"<title>{int(day[-2:])}日 {escape(label)} {number(value, percent)}</title></circle>")
            last = index
        if not path:
            continue
        parts.append(f'<path d="{" ".join(path)}" fill="none" stroke="{color}" stroke-width="2" '
                     f'stroke-linejoin="round" stroke-linecap="round"/>')
        end = max(index for index, day in enumerate(days) if points.get(day) is not None)
        end_value = points[days[end]]
        parts.append(f'<circle cx="{x(end):.1f}" cy="{y(end_value):.1f}" r="4" fill="{color}" '
                     f'stroke="{SURFACE}" stroke-width="2"/>')
        label_y = y(end_value) + 4
        for other in label_ys:
            if abs(label_y - other) < 14:
                label_y = other + 14 if label_y >= other else other - 14
        label_ys.append(label_y)
        parts.append(f'<text x="{x(end) + 10:.1f}" y="{label_y:.1f}" font-size="12" fill="{INK_2}">'
                     f"{number(end_value, percent)}</text>")
    return frame(title, "\n".join(parts) + "\n")


def bar_chart(title, items):
    row = 32
    height = TOP + row * max(len(items), 1) + 16
    label_w = 150
    bar_w = WIDTH - 24 - label_w - 90
    top = max((value for _, value in items), default=0) or 1
    parts = []
    for index, (label, value) in enumerate(items):
        middle = TOP + index * row + row / 2
        length = max(value / top * bar_w, 0)
        left = 24 + label_w
        parts.append(f'<text x="{left - 10}" y="{middle + 4:.1f}" font-size="12" fill="{INK_2}" '
                     f'text-anchor="end">{escape(label)}</text>')
        if length > 0:
            radius = min(4, length)
            parts.append(
                f'<path d="M{left},{middle - 8:.1f} h{length - radius:.1f} a{radius},{radius} 0 0 1 {radius},{radius} '
                f'v{16 - 2 * radius} a{radius},{radius} 0 0 1 -{radius},{radius} h-{length - radius:.1f} z" '
                f'fill="{SERIES[0]}"><title>{escape(label)} {value:,}</title></path>')
        parts.append(f'<text x="{left + length + 8:.1f}" y="{middle + 4:.1f}" font-size="12" fill="{INK_2}">'
                     f"{value:,}</text>")
    parts.append(f'<line x1="{24 + label_w}" x2="{24 + label_w}" y1="{TOP - 6}" y2="{height - 12}" '
                 f'stroke="{AXIS}" stroke-width="1"/>')
    return frame(title, "\n".join(parts) + "\n", height)


def rate(numerator, denominator):
    return numerator / denominator * 100 if denominator else None


def charts(funnel):
    days_data = funnel["month"]["days"]
    days = sorted(days_data)
    impressions = {day: days_data[day]["impressions"] for day in days}
    page_views = {day: days_data[day]["page_views"] for day in days}
    open_rate = {day: rate(days_data[day]["page_views"], days_data[day]["impressions"]) for day in days}
    install_rate = {day: rate(days_data[day]["downloads"], days_data[day]["page_views"]) for day in days}
    sources = sorted(funnel["month"]["sources"].items(), key=lambda item: -item[1]["page_views"])
    return [
        ("funnel-daily", "日ごとのインプレッション", line_chart(
            "日ごとのインプレッション", days, [("インプレッション", impressions)])),
        ("funnel-views", "日ごとの閲覧", line_chart("日ごとのプロダクトページの閲覧", days, [("閲覧", page_views)])),
        ("funnel-rates", "日ごとの割合", line_chart(
            "日ごとの割合", days, [("閲覧 ÷ インプレッション", open_rate), ("初回 DL ÷ 閲覧", install_rate)], percent=True)),
        ("funnel-sources", "ソース別の閲覧", bar_chart(
            "ソース別のプロダクトページの閲覧", [(SOURCES.get(name, name), value["page_views"]) for name, value in sources])),
    ]


def write_charts(funnel, out_dir, prefix):
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for name, alt, svg in charts(funnel):
        path = os.path.join(out_dir, f"{prefix}-{name}.svg")
        Path(path).write_text(svg, encoding="utf-8")
        written.append((alt, path))
    return written


def main():
    if len(sys.argv) < 4:
        fail("使い方: render-charts.py <fetch-analytics.py の JSON> <出力先のフォルダ> <名前の頭>")
    try:
        funnel = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise Failure(f"JSON を読めない: {sys.argv[1]}") from error
    for _, path in write_charts(funnel, sys.argv[2], sys.argv[3]):
        print(path)


if __name__ == "__main__":
    run_main(main)
