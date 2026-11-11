import collections
import os
import re

from bin.config_audit.files import LAYOUT, layout_table, place_matches, read, tracked_files
from loader import ROOT

PLACES_HEADING = "### 置ける場所の表"
LIMITS_HEADING = "### 分ける合図の表"
COUNT_ALL = "全部"
COUNT_HEAD = "同じ頭"
COUNT_FOLDER = "子フォルダ"
COUNTS = (COUNT_ALL, COUNT_HEAD, COUNT_FOLDER)
INSTALL = os.path.join(ROOT, "bin", "config-install.sh")
DELIVERED = "dotclaude/"
NOT_INSTALLED = {"README.md"}


def cell_patterns(cell):
    return [pattern.strip("` ") for pattern in cell.split("・")]


def places():
    return [pattern for row in layout_table(PLACES_HEADING, "場所") for pattern in cell_patterns(row[0])]


def check_places():
    patterns = places()
    if not patterns:
        yield LAYOUT, 1, "フォルダの分け方の置ける場所の表が読めない"
        return
    used = set()
    for path in tracked_files():
        found = [pattern for pattern in patterns if place_matches(path, pattern)]
        used.update(found)
        if not found:
            yield os.path.join(ROOT, path), 1, "置ける場所の表に無い場所にある。置き場所を直すか、表に行を足す"
    for pattern in patterns:
        if pattern not in used:
            yield LAYOUT, 1, f"置ける場所の表の場所に、当たるファイルが無い: {pattern}"


def head_of(name):
    return re.split(r"[-_.]", name, maxsplit=1)[0]


def counted_name(path, pattern):
    wants = pattern.split("/")
    index = next((index for index, want in enumerate(wants) if "*" in want), len(wants) - 1)
    return path.split("/")[index]


def check_limits():
    rows = layout_table(LIMITS_HEADING, "場所")
    if not rows:
        yield LAYOUT, 1, "フォルダの分け方の分ける合図の表が読めない"
        return
    for row in rows:
        pattern, counted, limit, how = (row + [""] * 4)[:4]
        if counted not in COUNTS or not limit.isdigit():
            yield LAYOUT, 1, f"分ける合図の表の行は、数えるものを {'・'.join(COUNTS)} のどれか、上限を数字にする: {pattern}"
            continue
        names = [counted_name(path, pattern) for path in tracked_files() if place_matches(path, pattern)]
        if not names:
            yield LAYOUT, 1, f"分ける合図の表の場所に、当たるファイルが無い: {pattern}"
        if counted == COUNT_FOLDER:
            if len(set(names)) > int(limit):
                yield LAYOUT, 1, f"{pattern} の子フォルダが {len(set(names))} 個で、上限の {limit} 個を超えた。{how}"
            continue
        groups = collections.Counter(head_of(name) if counted == COUNT_HEAD else "" for name in names)
        for head, count in sorted(groups.items()):
            if count > int(limit):
                what = f"頭が {head} のファイル" if head else "ファイル"
                yield LAYOUT, 1, f"{pattern} の{what}が {count} 本で、上限の {limit} 本を超えた。{how}"


def check_install_targets():
    script = read(INSTALL)
    names = sorted({path.split("/")[1] for path in tracked_files() if path.startswith(DELIVERED)} - NOT_INSTALLED)
    for name in names:
        if not re.search(rf'dotclaude"?/{re.escape(name)}(?![A-Za-z0-9_-])', script):
            yield INSTALL, 1, f"dotclaude/{name} を入れる処理が config-install.sh に無い"
