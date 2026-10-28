import sys

ANCHOR = "    targets: [\n"


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        fail("使い方: add-target.py <マニフェスト> <ターゲット一覧>")
    manifest, targets = sys.argv[1], sys.argv[2]

    dependencies = []
    for line in open(targets, encoding="utf-8").read().split():
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

    text = open(manifest, encoding="utf-8").read()
    if ANCHOR not in text:
        fail(f"targets: [ が見つからない: {manifest}")
    open(manifest, "w", encoding="utf-8").write(text.replace(ANCHOR, ANCHOR + target, 1))


if __name__ == "__main__":
    main()
