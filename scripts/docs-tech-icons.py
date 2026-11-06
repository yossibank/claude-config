import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

CDN = "https://cdn.simpleicons.org/{slug}/white"
ITEM = re.compile(r"^([a-z0-9]+):([0-9A-Fa-f]{6}):([^:]+)(?::([^:]+))?$")
PATH = re.compile(r"<path\b[^>]*/>")
STEP = 112
TILE = 88
FONT = '-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif'
USAGE = "NG 使い方: docs-tech-icons.py [--icons <フォルダ>] <出力.svg> <slug>:<色>:<名前>[:<版>]..."


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def parse(args):
    icons = None
    if args[:1] == ["--icons"]:
        if len(args) < 2:
            fail(USAGE[3:])
        icons, args = Path(args[1]), args[2:]
    if len(args) < 2:
        fail(USAGE[3:])
    items = []
    for arg in args[1:]:
        match = ITEM.match(arg)
        if not match:
            fail(f"形が違う: {arg}。<slug>:<6 桁の色>:<名前>[:<版>] にする")
        items.append(match.groups())
    return icons, Path(args[0]), items


def icon_paths(slug, icons):
    if icons:
        try:
            svg = (icons / f"{slug}.svg").read_text(encoding="utf-8")
        except OSError:
            fail(f"アイコンが無い: {icons / f'{slug}.svg'}")
    else:
        try:
            request = urllib.request.Request(CDN.format(slug=slug), headers={"User-Agent": "docs-tech-icons"})
            with urllib.request.urlopen(request, timeout=20) as response:
                svg = response.read().decode("utf-8")
        except (urllib.error.URLError, TimeoutError):
            fail(f"Simple Icons から取れない: {slug}")
    paths = "".join(PATH.findall(svg))
    if not paths:
        fail(f"アイコンに path が無い: {slug}")
    return paths


def tile(index, slug, color, name, version, icons):
    x = index * STEP + (STEP - TILE) // 2
    middle = TILE // 2
    lines = [
        f'<g transform="translate({x} 8)">',
        f'<rect width="{TILE}" height="{TILE}" rx="22" fill="#{color}"/>',
        f'<rect width="{TILE}" height="{TILE}" rx="22" fill="url(#shine)"/>',
        f'<g transform="translate(22 22) scale(1.8333)" fill="#fff">{icon_paths(slug, icons)}</g>',
        f'<text x="{middle}" y="118" text-anchor="middle" class="name">{escape(name)}</text>',
    ]
    if version:
        lines.append(f'<text x="{middle}" y="138" text-anchor="middle" class="version">{escape(version)}</text>')
    lines.append("</g>")
    return "".join(lines)


def render(items, icons):
    width = len(items) * STEP
    height = 148 if any(version for *_, version in items) else 128
    tiles = "".join(tile(index, *item, icons) for index, item in enumerate(items))
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
        '<defs><linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#fff" stop-opacity="0.18"/>'
        '<stop offset="1" stop-color="#fff" stop-opacity="0"/>'
        "</linearGradient><style>"
        f".name{{font:600 15px {FONT};fill:#8b949e}}"
        f".version{{font:500 13px {FONT};fill:#8b949e}}"
        f"</style></defs>{tiles}</svg>\n"
    )


def main():
    icons, out, items = parse(sys.argv[1:])
    svg = render(items, icons)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(svg, encoding="utf-8")
    print(f"OK {out}（{len(items)} 個）")


if __name__ == "__main__":
    main()
