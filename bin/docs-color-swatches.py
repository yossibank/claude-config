import os
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "lib"))

from script_io import fail, run_main  # noqa: E402

ITEM = re.compile(r"^([^:]+):([0-9A-Fa-f]{6})(?::([0-9A-Fa-f]{6}))?$")
ROW = 40
SWATCH = 28
GAP = 10
COLUMN = 120
HEADER = 28
PAD = 8
WIDE = 14
NARROW = 8
FONT = '-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif'
MODES = ["ライト", "ダーク"]
USAGE = "NG 使い方: docs-color-swatches.py <出力.svg> <名前>:<ライトの色>[:<ダークの色>]..."


def parse(args):
    if len(args) < 2:
        fail(USAGE[3:])
    items = []
    for arg in args[1:]:
        match = ITEM.match(arg)
        if not match:
            fail(f"形が違う: {arg}。<名前>:<6 桁の色>[:<6 桁の色>] にする")
        name, light, dark = match.groups()
        items.append((name, light.upper(), dark.upper() if dark else None))
    return Path(args[0]), items


def text_width(text):
    return sum(NARROW if ord(char) < 0x2E80 else WIDE for char in text)


def swatch(x, y, color):
    return (
        f'<rect x="{x}" y="{y + (ROW - SWATCH) // 2}" width="{SWATCH}" height="{SWATCH}" rx="6" '
        f'fill="#{color}" stroke="#8b949e" stroke-opacity="0.5"/>'
        f'<text x="{x + SWATCH + GAP}" y="{y + ROW // 2 + 5}" class="value">#{color}</text>'
    )


def render(items):
    columns = 2 if any(dark for *_, dark in items) else 1
    name_width = max(text_width(name) for name, *_ in items) + 2 * GAP
    top = HEADER if columns == 2 else 0
    width = PAD * 2 + name_width + columns * COLUMN
    height = PAD * 2 + top + len(items) * ROW
    parts = []
    if columns == 2:
        for index, mode in enumerate(MODES):
            x = PAD + name_width + index * COLUMN
            parts.append(f'<text x="{x}" y="{PAD + HEADER - 10}" class="mode">{mode}</text>')
    for index, (name, light, dark) in enumerate(items):
        y = PAD + top + index * ROW
        parts.append(f'<text x="{PAD}" y="{y + ROW // 2 + 5}" class="name">{escape(name)}</text>')
        for column, color in enumerate([light, dark][:columns]):
            if color:
                parts.append(swatch(PAD + name_width + column * COLUMN, y, color))
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
        "<defs><style>"
        f".name{{font:600 14px {FONT};fill:#8b949e}}"
        f".mode{{font:600 13px {FONT};fill:#8b949e}}"
        f'.value{{font:500 13px ui-monospace,SFMono-Regular,Menlo,monospace;fill:#8b949e}}'
        f"</style></defs>{''.join(parts)}</svg>\n"
    )


def main():
    out, items = parse(sys.argv[1:])
    svg = render(items)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(svg, encoding="utf-8")
    print(f"OK {out}（{len(items)} 色）")


if __name__ == "__main__":
    run_main(main)
