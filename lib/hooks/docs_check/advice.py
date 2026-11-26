import os
import re

SIZE_LIMIT = 15_000
SIZE_WARNING = SIZE_LIMIT * 9 // 10
NO_CHAIN = 4

NO_RUN = re.compile(rf"(?:[^、。・のとをでにはがやも\s|「」（）()]{{1,6}}\s?(?<!な)の\s?){{{NO_CHAIN},}}")


def check_size_near(doc):
    size = os.path.getsize(doc.path)
    if doc.in_docs and SIZE_WARNING < size <= SIZE_LIMIT:
        return [(1, f"docs の 1 ファイルが上限 {SIZE_LIMIT // 1000}KB の 9 割を超えた（{size / 1000:.1f}KB）。分ける節を決めておく")]
    return []


def check_no_chains(doc):
    found = []
    for row in doc.rows:
        if row.what in ("code", "math", "blank", "heading"):
            continue
        chain = NO_RUN.search(row.spoken)
        if chain:
            found.append((row.number, f"「の」を {NO_CHAIN} 回以上続けない（{chain.group(0).strip()}）。型名や動詞でほどく"))
    return found
