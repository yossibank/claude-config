import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from script_io import fail  # noqa: E402


def replace(text, tokens):
    for token, value in tokens:
        text = text.replace(token, value)
    return text


def summary_of(overview):
    lines = Path(overview).read_text(encoding="utf-8").split("\n")
    body = (line.strip() for line in lines[1:])
    first = next((line for line in body if line and not line.startswith(">")), "")
    if first.startswith(("<", "#", "|", "-")):
        return ""
    sentence, mark, _ = first.partition("。")
    return sentence + mark


def main():
    if len(sys.argv) < 5:
        fail("使い方: replace-placeholders.py <ルート> <パスカル> <小文字> <表示名>")
    root, pascal, lower, display = sys.argv[1:5]
    tokens = [("__DisplayName__", display), ("__App__", pascal), ("__app__", lower)]

    for directory, folders, files in os.walk(root, topdown=False):
        for file in files:
            path = os.path.join(directory, file)
            try:
                text = Path(path).read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            new = replace(text, tokens)
            if new != text:
                Path(path).write_text(new, encoding="utf-8")
        for item in files + folders:
            renamed = replace(item, tokens)
            if renamed != item:
                os.rename(os.path.join(directory, item), os.path.join(directory, renamed))

    readme = os.path.join(root, "README.md")
    summary = summary_of(os.path.join(root, "docs", "overview.md"))
    if summary:
        text = Path(readme).read_text(encoding="utf-8")
        Path(readme).write_text(text.replace("<何のアプリかを 1 文で>", summary), encoding="utf-8")


if __name__ == "__main__":
    main()
