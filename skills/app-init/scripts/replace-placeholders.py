import os
import sys


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def replace(text, tokens):
    for token, value in tokens:
        text = text.replace(token, value)
    return text


def main():
    if len(sys.argv) < 5:
        fail("使い方: replace-placeholders.py <ルート> <パスカル> <小文字> <表示名>")
    root, pascal, lower, display = sys.argv[1:5]
    tokens = [("__DisplayName__", display), ("__App__", pascal), ("__app__", lower)]

    for directory, folders, files in os.walk(root, topdown=False):
        for file in files:
            path = os.path.join(directory, file)
            try:
                text = open(path, encoding="utf-8").read()
            except UnicodeDecodeError:
                continue
            new = replace(text, tokens)
            if new != text:
                open(path, "w", encoding="utf-8").write(new)
        for item in files + folders:
            renamed = replace(item, tokens)
            if renamed != item:
                os.rename(os.path.join(directory, item), os.path.join(directory, renamed))

    overview = os.path.join(root, "docs", "overview.md")
    readme = os.path.join(root, "README.md")
    lines = open(overview, encoding="utf-8").read().split("\n")
    summary = lines[2] if len(lines) > 2 else ""
    if summary and not summary.startswith("<"):
        text = open(readme, encoding="utf-8").read()
        open(readme, "w", encoding="utf-8").write(text.replace("<何のアプリかを 1 文で>", summary))


if __name__ == "__main__":
    main()
