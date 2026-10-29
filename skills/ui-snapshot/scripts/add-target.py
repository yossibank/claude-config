import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from script_io import fail  # noqa: E402

ANCHOR = "    targets: [\n"


def main():
    if len(sys.argv) < 3:
        fail("使い方: add-target.py <マニフェスト> <ターゲット一覧>")
    manifest, targets = sys.argv[1], sys.argv[2]

    dependencies = []
    for line in Path(targets).read_text(encoding="utf-8").split():
        if ":" in line:
            product, package = line.split(":", 1)
            dependencies.append(f'.product(name: "{product}", package: "{package}")')
        else:
            dependencies.append(f'"{line}"')

    target = (
        "        .testTarget(\n"
        '            name: "UISnapshotTests",\n'
        "            dependencies: [\n"
        + ",\n".join(f"                {dependency}" for dependency in dependencies)
        + "\n            ]\n"
        "        ),\n"
    )

    text = Path(manifest).read_text(encoding="utf-8")
    if ANCHOR not in text:
        fail(f"targets: [ が見つからない: {manifest}")
    Path(manifest).write_text(text.replace(ANCHOR, ANCHOR + target, 1), encoding="utf-8")


if __name__ == "__main__":
    main()
