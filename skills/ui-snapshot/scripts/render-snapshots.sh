#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/simulator.sh"

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <パッケージのフォルダ> <セットのフォルダ> <出力先のフォルダ>"; exit 1; }

[[ -d $1 ]] || { echo "NG パッケージのフォルダが無い: $1"; exit 1; }
[[ -d $2 ]] || { echo "NG セットのフォルダが無い: $2"; exit 1; }

skill=$(cd "$(dirname "$0")/.." && pwd)
package=$(cd "$1" && pwd)
set_dir=$(cd "$2" && pwd)
out=$(mkdir -p "$3" && cd "$3" && pwd)
tests="$package/Tests/UISnapshotTests"

[[ -f $set_dir/SnapshotTests.swift ]] || { echo "NG セットに SnapshotTests.swift が無い: $set_dir"; exit 1; }
[[ -f $set_dir/targets.txt ]] || { echo "NG セットに targets.txt が無い: $set_dir"; exit 1; }
case "$out/" in
    "$package"/*) echo "NG 出力先がパッケージの中にある: ${out}。戻す時に消えるので、パッケージの外を渡す"; exit 1 ;;
esac
marker="$out/.ui-snapshot"
if [[ ! -f $marker && -n $(ls -A "$out") ]]; then
    echo "NG 出力先が空でなく、ui-snapshot の出力先でもない: ${out}。空のフォルダを渡す"
    exit 1
fi
[[ -e $tests ]] && { echo "NG 前の回の後片付けが済んでいない: ${tests}。退避のフォルダから戻すか、git で戻してから走らせる"; exit 1; }

device=$(pick_iphone)
[[ -n $device ]] || { echo "NG iPhone のシミュレーターが無い。CC_UI_DEVICE に UDID を渡す"; exit 1; }
scheme=$(cd "$package" && xcodebuild -list -json 2>/dev/null | jq -r '.workspace.schemes as $all | ([$all[] | select(endswith("-Package"))] + $all)[0] // empty')
[[ -n $scheme ]] || { echo "NG パッケージのスキームが見つからない: $package"; exit 1; }

backup=$(mktemp -d)
echo "退避: $backup"
rsync -a --exclude .git --exclude .build --exclude .swiftpm "$package/" "$backup/"

restore() {
    rm -rf "$tests"
    rsync -a --delete --exclude .git --exclude .build --exclude .swiftpm "$backup/" "$package/" && rm -rf "$backup"
}

trap restore EXIT

python3 -I "$skill/scripts/add-target.py" "$package/Package.swift" "$set_dir/targets.txt"
[[ -f $set_dir/patch.py ]] && python3 -I "$set_dir/patch.py" "$package"
mkdir -p "$tests"
source_text=$(<"$set_dir/SnapshotTests.swift")
printf '%s\n' "${source_text//__OUT__/"$out"}" >|"$tests/SnapshotTests.swift"
rm -f "$out"/*.png
touch "$marker"

cd "$package"

set +e
xcodebuild test \
    -scheme "$scheme" \
    -destination "id=$device" \
    -only-testing:UISnapshotTests 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
status=${PIPESTATUS[0]}
set -e

[[ $status -eq 0 ]] || { echo "NG テストが通らなかった（xcodebuild: ${status}）"; exit "${status}"; }
compgen -G "$out/*.png" >/dev/null || { echo "NG PNG が描かれなかった: $out"; exit 1; }
ls "$out"/*.png
