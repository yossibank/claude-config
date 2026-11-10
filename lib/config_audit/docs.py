import functools
import os
import re

from config_audit.files import NAMING, naming_table, outside_code, read, skill_names, tracked, tracked_files
from loader import DOTCLAUDE, ROOT, load_hook
from md_blocks import heading_of
from md_doc import body_emojis, heading_emojis, read_doc, readme_order


LEDGERS = [os.path.join(ROOT, "docs", "config", "improvements.md")]
COMPONENT_DOCS = ["components.md", "skills.md"]
LEDGER_SECTION = "## 📝 残っている改善"
BACKTICKED = re.compile(r"`([^`]+)`")
LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")
ANCHOR_LINK = re.compile(r"\]\(([^)#\s]*)#([^)\s]+)\)")
INLINE_CODE = re.compile(r"`[^`]*`")
UNCHECKED_ROOTS = {"docs"}
APP_TEMPLATE = os.path.join(DOTCLAUDE, "skills", "app-init", "templates", "ios-app")


def check_readme():
    docs = [os.path.join(ROOT, "docs", "config", name) for name in COMPONENT_DOCS]
    links = {os.path.normpath(os.path.join("docs", "config", target.rstrip("/"))) for path in docs for target in LINK.findall(read(path))}
    entries = [f"dotclaude/skills/{name}/SKILL.md" for name in skill_names()]
    entries += [os.path.relpath(path, ROOT) for path in tracked("dotclaude/agents/*.md", "dotclaude/output-styles/*.md", "dotclaude/rules/*.md", "dotclaude/hooks/*.py", "dotclaude/hooks/*.sh", "scripts/*")]
    for entry in entries:
        if entry not in links:
            yield docs[0], 1, f"部品の文書の表に載っていない: {entry}"


def check_readme_flow():
    skills = os.path.join(ROOT, "docs", "config", "skills.md")
    flow = "".join(re.findall(r"```mermaid\n(.*?)```", read(skills), re.S))
    if not flow:
        yield skills, 1, "スキルを使う順の Mermaid の図が無い"
        return
    for name in skill_names():
        if not re.search(rf"(?<![A-Za-z0-9_-]){re.escape(name)}(?![A-Za-z0-9_-])", flow):
            yield skills, 1, f"スキルを使う順の図に載っていない: {name}"


def check_links():
    for path in tracked("*.md"):
        template = "/templates/" in path
        for number, line in outside_code(path):
            for target in LINK.findall(line):
                if re.match(r"[a-z]+:", target) or target.startswith("<"):
                    continue
                if template and ("<" in target or "__" in target):
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                if not os.path.exists(resolved):
                    yield path, number, f"リンク先が無い: {target}"


def slug(title):
    text = re.sub(r"[^\w\- ]", "", title.replace("`", "").strip().lower())
    return text.replace(" ", "-")


@functools.cache
def anchors_of(path):
    anchors = set()
    for _, line in outside_code(path):
        heading = heading_of(line)
        if heading and heading[0] <= 6:
            base = slug(heading[1])
            anchor, count = base, 0
            while anchor in anchors:
                count += 1
                anchor = f"{base}-{count}"
            anchors.add(anchor)
    return anchors


def check_anchors():
    for path in tracked("*.md"):
        for number, line in outside_code(path):
            for target, anchor in ANCHOR_LINK.findall(INLINE_CODE.sub("", line)):
                if re.match(r"[a-z]+:", target):
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target)) if target else path
                if resolved.endswith(".md") and os.path.isfile(resolved) and anchor not in anchors_of(resolved):
                    yield path, number, f"リンク先の見出しが無い: {target}#{anchor}"


def path_bases(path):
    bases = [ROOT, os.path.dirname(path), APP_TEMPLATE]
    parts = os.path.relpath(path, DOTCLAUDE).split(os.sep)
    if parts[0] != os.pardir:
        bases.append(DOTCLAUDE)
    if parts[0] == "skills" and len(parts) > 2:
        bases.append(os.path.join(DOTCLAUDE, "skills", parts[1]))
    return bases


@functools.cache
def path_ref():
    folders = {path.split("/")[0] for path in tracked_files() if "/" in path} - UNCHECKED_ROOTS
    folders |= {path.split("/")[1] for path in tracked_files() if path.startswith("dotclaude/") and path.count("/") > 1}
    names = "|".join(re.escape(name) for name in sorted(folders))
    return re.compile(rf"(?<![\w./~-])((?:{names})/[A-Za-z0-9_./-]*)(.?)")


def check_paths():
    for path in tracked("*.md"):
        for number, line in outside_code(path):
            for reference, after in path_ref().findall(line):
                reference = reference.rstrip(".")
                if after in ("<", "*") or any(os.path.exists(os.path.join(base, reference)) for base in path_bases(path)):
                    continue
                yield path, number, f"参照先が無い: {reference}"


def check_ledger():
    for ledger in LEDGERS:
        if not os.path.exists(ledger):
            yield ledger, 0, "台帳が無い"
            continue
        in_section = False
        for number, line in enumerate(read(ledger).split("\n"), 1):
            if line.startswith("## "):
                in_section = line == LEDGER_SECTION
            if not in_section or not line.startswith("|"):
                continue
            cells = [cell.strip() for cell in line.strip("|").split("|")]
            if len(cells) < 3 or cells[1] == "場所" or set(cells[1]) <= {"-", " "}:
                continue
            found = BACKTICKED.match(cells[1])
            if not found:
                yield ledger, number, f"台帳の場所の先頭にパスが無い: {cells[1]}"
            elif not os.path.exists(os.path.join(ROOT, found.group(1))):
                yield ledger, number, f"台帳の場所のパスが無い: {found.group(1)}"


def check_docs():
    docs = load_hook("docs-check")
    if not heading_emojis() or not body_emojis() or not readme_order():
        yield os.path.join(DOTCLAUDE, "rules", "docs-human.md"), 1, "見出しの絵文字・本文の絵文字・README の形のどれかの表が読めない"
    for path in tracked("*.md"):
        for number, message in docs.check(path):
            yield path, number, message


def term_pattern(word):
    edge = r"[A-Za-z0-9_./-]"
    return re.compile(rf"(?<!{edge}){re.escape(word)}(?!{edge})" if word.isascii() else re.escape(word))


def check_terms():
    table = naming_table("### そろえる語", "使う語")
    if not table:
        yield NAMING, 1, "名前の付け方のそろえる語の表が読めない"
        return
    patterns = [(use, avoid, term_pattern(avoid)) for use, avoid in table]
    for path in tracked("*.md"):
        for row in read_doc(path).rows:
            for use, avoid, pattern in patterns:
                if path == NAMING and row.text.strip().startswith(f"| {use} |"):
                    continue
                if pattern.search(row.text):
                    yield path, row.number, f"「{avoid}」ではなく「{use}」と書く（そろえる語の表）"
