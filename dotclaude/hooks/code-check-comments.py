import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

import kotlin_source  # noqa: E402
import shell_source  # noqa: E402
import swift_source  # noqa: E402
from hook_baseline import VERIFY_PREFIX, from_verify  # noqa: E402
from hook_io import block_on_findings, run_gate, run_hook, target_paths  # noqa: E402

HEADER = "コメントがある（rules/code-comments.md）。消す。要ると判断したら、書かずに提案する。"
MESSAGE = "コメントを消す"
MASKS = {".swift": swift_source.mask, ".kt": kotlin_source.mask, ".kts": kotlin_source.mask}
SHELL_LIKE = (".sh",)
CONFIGS = (".yml", ".yaml", ".toml")
QUOTE_AFTER = set(" \t:=[{,")
NAMES = {"Makefile"}
FIRST_LINE = ("#!", "// swift-tools-version:")
DIRECTIVE = re.compile(r"^(?://|/\*|#)\s*(?:swiftlint:|swiftformat:|shellcheck\s|ktlint-|@formatter:|yaml-language-server:)")


def is_target(path):
    return path.endswith((*MASKS, *SHELL_LIKE, *CONFIGS)) or os.path.basename(path) in NAMES


def config_comment(line):
    quote = None
    index = 0
    while index < len(line):
        char = line[index]
        before = line[index - 1] if index else " "
        if quote:
            if char == "\\" and quote == '"':
                index += 1
            elif char == quote:
                quote = None
        elif char in "'\"" and before in QUOTE_AFTER:
            quote = char
        elif char == "#" and before in " \t":
            return line[index:]
        index += 1
    return None


def config_comments(text):
    for number, line in enumerate(text.split("\n"), 1):
        body = config_comment(line)
        if body is not None:
            yield number, body


def comments_of(path, text):
    if path.endswith(CONFIGS):
        return list(config_comments(text))
    mask = MASKS.get(os.path.splitext(path)[1])
    if mask is None:
        return list(shell_source.comments(text))
    found = []
    mask(text, found)
    return found


def is_kept(number, body):
    return (number == 1 and body.startswith(FIRST_LINE)) or bool(DIRECTIVE.match(body))


def check(path):
    with open(path, encoding="utf-8") as file:
        text = file.read()
    return [(number, MESSAGE) for number, body in comments_of(path, text) if not is_kept(number, body)]


def main():
    paths = [path for path in target_paths("") if is_target(path)]
    block_on_findings(HEADER, paths, check, VERIFY_PREFIX if from_verify() else "")


if __name__ == "__main__":
    if from_verify():
        run_gate("code-check-comments", main, VERIFY_PREFIX)
    else:
        run_hook("code-check-comments", main)
