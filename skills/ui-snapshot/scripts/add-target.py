import sys

manifest, targets = sys.argv[1], sys.argv[2]
ANCHOR = "    targets: [\n"

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
    sys.exit(f"NG targets: [ が見つからない: {manifest}")
open(manifest, "w", encoding="utf-8").write(text.replace(ANCHOR, ANCHOR + target, 1))
