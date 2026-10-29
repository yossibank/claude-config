import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import read_payload, tool_input  # noqa: E402

LIMIT = 30_000
TEXT = (".md", ".swift", ".kt", ".json", ".txt", ".log", ".yml", ".yaml", ".csv")


def main():
    data = read_payload()
    if data is None:
        return
    tool = tool_input(data)
    path = tool.get("file_path", "")
    if not path.endswith(TEXT) or not os.path.isfile(path) or tool.get("limit"):
        return
    size = os.path.getsize(path)
    if size <= LIMIT:
        return
    print(
        f"{path} は {size // 1000}KB ある。丸ごと読まない。"
        "Markdown は docs-section.sh で見出しの一覧を出し、要る節だけを読む。"
        "ほかは Grep で場所を探し、offset と limit で範囲を絞って読む。",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
