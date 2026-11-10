import ast
import os
import re

from config_audit.files import headings, read, tracked
from loader import DOTCLAUDE, ROOT
from md_doc import rule_table

CONFIG_REF = re.compile(r"(?:claude-config|CLAUDE_CONFIG\)?\}?)/((?:(?:dotclaude/)?(?:skills/[a-z0-9-]+/scripts|hooks)|lib)/[A-Za-z0-9_.-]+)")
TEMPLATE_TOKEN = re.compile(r"__[A-Za-z]+__")
REPLACER = os.path.join(DOTCLAUDE, "skills", "app-init", "scripts", "replace-placeholders.py")


def check_template_scripts():
    files = [path for path in tracked("dotclaude/skills/*/templates/**") if path.endswith((".sh", "/Makefile"))]
    for path in files:
        for number, line in enumerate(read(path).split("\n"), 1):
            for reference in CONFIG_REF.findall(line):
                if not os.path.exists(os.path.join(ROOT, reference)):
                    yield path, number, f"claude-config の参照先が無い: {reference}"


def replacer_tokens(tree):
    for node in ast.walk(tree):
        if not isinstance(node, ast.List):
            continue
        for item in node.elts:
            if isinstance(item, ast.Tuple) and len(item.elts) == 2 and isinstance(item.elts[0], ast.Constant):
                yield item.lineno, item.elts[0].value


def literal_replaces(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "replace":
            if node.args and isinstance(node.args[0], ast.Constant):
                yield node.lineno, node.args[0].value


def template_tokens(path):
    yield 1, os.path.relpath(path, ROOT)
    try:
        yield from enumerate(read(path).split("\n"), 1)
    except UnicodeDecodeError:
        return


def check_template_tokens():
    tree = ast.parse(read(REPLACER))
    tokens = set()
    for number, token in replacer_tokens(tree):
        if isinstance(token, str) and TEMPLATE_TOKEN.fullmatch(token):
            tokens.add(token)
        else:
            yield REPLACER, number, f"tokens に __<名前>__ でない文字列がある: {token}"
    for number, text in literal_replaces(tree):
        yield REPLACER, number, f"tokens を通さずに文字列を置き換えている: {text}"
    for path in tracked("dotclaude/skills/app-init/templates/**"):
        for number, line in template_tokens(path):
            for token in sorted(set(TEMPLATE_TOKEN.findall(line)) - tokens):
                yield path, number, f"replace-placeholders.py の tokens に無い印: {token}"


def check_claude_templates():
    order = [row[1] for row in rule_table("## CLAUDE.md の形", "順")][1:-1]
    if not order:
        yield os.path.join(DOTCLAUDE, "rules", "docs-claude.md"), 1, "CLAUDE.md の形の表が読めない"
        return
    for path in tracked("dotclaude/skills/*/templates/*/CLAUDE.md"):
        top = 0
        for number, name in headings(path):
            rank = order.index(name) if name in order else len(order)
            if rank < top:
                yield path, number, f"CLAUDE.md の ## は {'・'.join(order)}・ほかの節の順に並べる"
            top = max(top, rank)
