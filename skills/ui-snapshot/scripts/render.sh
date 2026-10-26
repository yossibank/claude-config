#!/bin/bash
set -euo pipefail

skill=$(cd "$(dirname "$0")/.." && pwd)
package=$(cd "${1:?パッケージのフォルダ}" && pwd)
set_dir=$(cd "${2:?セットのフォルダ}" && pwd)
out=$(mkdir -p "${3:?出力先のフォルダ}" && cd "$3" && pwd)
tests="$package/Tests/UISnapshotTests"

[ -f "$set_dir/SnapshotTests.swift" ] || { echo "NG セットに SnapshotTests.swift が無い: $set_dir"; exit 1; }
[ -f "$set_dir/targets.txt" ] || { echo "NG セットに targets.txt が無い: $set_dir"; exit 1; }
[ -e "$tests" ] && { echo "NG 前の回の後片付けが済んでいない: $tests。退避のフォルダから戻すか、git で戻してから走らせる"; exit 1; }

device="${DEVICE:-$(xcrun simctl list devices available iPhone | awk -F '[()]' '/iPhone/ { print $2; exit }')}"
scheme=$(cd "$package" && xcodebuild -list -json 2>/dev/null | python3 -I -c '
import json, sys
schemes = json.load(sys.stdin)["workspace"]["schemes"]
package = [s for s in schemes if s.endswith("-Package")]
print((package or schemes or [""])[0])
')
[ -n "$scheme" ] || { echo "NG パッケージのスキームが見つからない: $package"; exit 1; }

backup=$(mktemp -d)
echo "退避: $backup"
rsync -a --exclude .build --exclude .swiftpm "$package/" "$backup/"

restore() {
    rm -rf "$tests"
    rsync -a --exclude .build --exclude .swiftpm "$backup/" "$package/" && rm -rf "$backup"
}

trap restore EXIT

python3 -I "$skill/scripts/add-target.py" "$package/Package.swift" "$set_dir/targets.txt"
[ -f "$set_dir/patch.py" ] && python3 -I "$set_dir/patch.py" "$package"
mkdir -p "$tests"
python3 -I -c 'import sys; open(sys.argv[3], "w", encoding="utf-8").write(open(sys.argv[1], encoding="utf-8").read().replace("__OUT__", sys.argv[2]))' \
    "$set_dir/SnapshotTests.swift" "$out" "$tests/SnapshotTests.swift"
rm -f "$out"/*.png

cd "$package"

set +e
xcodebuild test \
    -scheme "$scheme" \
    -destination "id=$device" \
    -only-testing:UISnapshotTests 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
status=${PIPESTATUS[0]}
set -e

[ "$status" -eq 0 ] || { echo "NG テストが通らなかった（xcodebuild: ${status}）"; exit "${status}"; }
ls "$out"/*.png
