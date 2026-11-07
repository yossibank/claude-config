#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/build_log.sh"

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <パッケージのフォルダ> <セットのフォルダ> <出力先のフォルダ>"; exit 1; }

[[ -d $1 ]] || { echo "NG パッケージのフォルダが無い: $1"; exit 1; }
[[ -d $2 ]] || { echo "NG セットのフォルダが無い: $2"; exit 1; }

skill=$(cd "$(dirname "$0")/.." && pwd)
package=$(cd "$1" && pwd -P)
set_dir=$(cd "$2" && pwd)
out=$(mkdir -p "$3" && cd "$3" && pwd)

[[ -f $set_dir/SnapshotTests.swift ]] || { echo "NG セットに SnapshotTests.swift が無い: $set_dir"; exit 1; }
[[ -f $set_dir/targets.txt ]] || { echo "NG セットに targets.txt が無い: $set_dir"; exit 1; }
marker="$out/.ui-snapshot"
if [[ ! -f $marker && -n $(ls -A "$out") ]]; then
    echo "NG 出力先が空でなく、ui-snapshot の出力先でもない: ${out}。空のフォルダを渡す"
    exit 1
fi

device=${CC_UI_DEVICE:-$("$skill/scripts/find-simulator.sh" || true)}
[[ -n $device ]] || { echo "NG iPhone のシミュレーターが無い。CC_UI_DEVICE に UDID を渡す"; exit 1; }
scheme=$(cd "$package" && xcodebuild -list -json 2>/dev/null | jq -r '.workspace.schemes as $all | ([$all[] | select(endswith("-Package"))] + $all)[0] // empty') || scheme=""
[[ -n $scheme ]] || { echo "NG パッケージのスキームが見つからない: $package"; exit 1; }

root=$(git -C "$package" rev-parse --show-toplevel 2>/dev/null || true)
[[ -n $root && $package/ == "$root"/* ]] || root=$package
key=$(printf '%s' "$root" | shasum | cut -c1-12)
copy="${CC_UI_WORK_DIR:-$HOME/Library/Caches/ui-snapshot}/$(basename "$root")-$key"
work="$copy${package#"$root"}"
tests="$work/Tests/UISnapshotTests"
lock="$copy.lock"

mkdir -p "$(dirname "$copy")"
if ! mkdir "$lock" 2>/dev/null; then
    holder=$(cat "$lock/pid" 2>/dev/null || true)
    if [[ -n $holder ]] && ! kill -0 "$holder" 2>/dev/null; then
        rm -rf "$lock"
    fi
    mkdir "$lock" 2>/dev/null || { echo "NG 同じリポジトリを描いている途中: ${lock}。終わるのを待つか、止まっていればフォルダを消す"; exit 1; }
fi
stage="$out/.rendering"
trap 'rm -rf "$lock" "$stage"' EXIT
echo $$ >"$lock/pid"
mkdir -p "$copy"
rsync -a --delete --exclude .git --exclude .build --exclude DerivedData --filter=':- .gitignore' "$root/" "$copy/"

python3 -I "$skill/scripts/add-target.py" "$work/Package.swift" "$set_dir/targets.txt"
[[ -f $set_dir/patch.py ]] && python3 -I "$set_dir/patch.py" "$work"
mkdir -p "$tests"
source_text=$(<"$set_dir/SnapshotTests.swift")
shopt -u patsub_replacement 2>/dev/null || true
test_text=${source_text//__OUT__/$stage}
printf '%s\n' "$test_text" >|"$tests/SnapshotTests.swift"
rm -rf "$stage"
mkdir -p "$stage"
touch "$marker"

cd "$work"

log="$work/.build/ui-snapshot.log"
mkdir -p "$(dirname "$log")"
status=0
xcodebuild test \
    -scheme "$scheme" \
    -destination "id=$device" \
    -collect-test-diagnostics never \
    -only-testing:UISnapshotTests >|"$log" 2>&1 || status=$?

if [[ $status -ne 0 ]]; then
    show_errors "$log"
    echo "NG テストが通らなかった（xcodebuild: ${status}、ログ: ${log}）"
    exit 1
fi
compgen -G "$stage/*.png" >/dev/null || { echo "NG PNG が描かれなかった（ログ: ${log}）"; exit 1; }
rm -f "$out"/*.png
mv "$stage"/*.png "$out/"
ls "$out"/*.png
