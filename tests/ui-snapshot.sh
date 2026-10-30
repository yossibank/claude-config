#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

find_simulator="$root/skills/ui-snapshot/scripts/find-simulator.sh"
fake_command xcrun "echo '{\"devices\":{\"rt\":[{\"name\":\"iPad Air\",\"udid\":\"PAD\"},{\"name\":\"iPhone 17\",\"udid\":\"PHONE\"}]}}'"
check "find-simulator: 先頭の iPhone の UDID を出す" test "$("$find_simulator")" == PHONE
fake_command xcrun "echo '{\"devices\":{}}'"
check "find-simulator: iPhone が無ければ何も出さない" test -z "$("$find_simulator")"
check "find-simulator: app-init のひな形と中身が同じ" cmp -s "$find_simulator" "$root/skills/app-init/templates/ios-app/scripts/find-simulator.sh"

add_target="$root/skills/ui-snapshot/scripts/add-target.py"
manifest="$work/Package.swift"
cat >"$manifest" <<'SWIFT'
let package = Package(
    name: "Kit",
    targets: [
        .target(name: "Core"),
    ]
)
SWIFT
printf 'Core\nSnapshotTesting:swift-snapshot-testing\n' >"$work/targets.txt"

expect "NG 使い方" "add-target: 引数が足りなければ NG" python3 -I "$add_target" "$manifest"
expect OK "add-target: テストのターゲットを足す" python3 -I "$add_target" "$manifest" "$work/targets.txt"
check "add-target: ターゲットの名前を書く" grep -q 'name: "UISnapshotTests"' "$manifest"
check "add-target: 同じパッケージのターゲットを依存に足す" grep -q '^                "Core",$' "$manifest"
check "add-target: ほかのパッケージの製品を依存に足す" grep -q '\.product(name: "SnapshotTesting", package: "swift-snapshot-testing")' "$manifest"

printf 'let package = Package(name: "Bare")\n' >"$work/Bare.swift"
expect "targets: [ が見つからない" "add-target: targets が無ければ NG" python3 -I "$add_target" "$work/Bare.swift" "$work/targets.txt"

render="$root/skills/ui-snapshot/scripts/render-snapshots.sh"
package="$work/pkg"
set_dir="$work/set"
mkdir -p "$package" "$set_dir"

expect "NG 使い方" "render-snapshots: 引数が足りなければ NG" bash "$render" "$package" "$set_dir"
expect "NG パッケージのフォルダが無い" "render-snapshots: パッケージが無ければ NG" bash "$render" "$work/none" "$set_dir" "$work/out"
expect "NG セットのフォルダが無い" "render-snapshots: セットが無ければ NG" bash "$render" "$package" "$work/none" "$work/out"
expect "NG セットに SnapshotTests.swift が無い" "render-snapshots: セットに SnapshotTests.swift が無ければ NG" bash "$render" "$package" "$set_dir" "$work/out"
touch "$set_dir/SnapshotTests.swift"
expect "NG セットに targets.txt が無い" "render-snapshots: セットに targets.txt が無ければ NG" bash "$render" "$package" "$set_dir" "$work/out"
touch "$set_dir/targets.txt"
mkdir -p "$work/busy"
touch "$work/busy/keep.txt"
expect "NG 出力先が空でなく" "render-snapshots: 出力先に別のファイルがあれば NG" bash "$render" "$package" "$set_dir" "$work/busy"
expect "NG iPhone のシミュレーターが無い" "render-snapshots: iPhone が無ければ NG" bash "$render" "$package" "$set_dir" "$work/out"
fake_command xcodebuild "echo '{\"workspace\":{\"schemes\":[]}}'"
CC_UI_DEVICE=MINE expect "NG パッケージのスキームが見つからない" "render-snapshots: CC_UI_DEVICE があれば iPhone を探さない" bash "$render" "$package" "$set_dir" "$work/out"
cp "$manifest" "$package/Package.swift"
printf 'Core\n' >"$set_dir/targets.txt"
printf 'let directory = "__OUT__"\n' >"$set_dir/SnapshotTests.swift"
fake_command xcodebuild "
if [[ \$1 == -list ]]; then
    echo '{\"workspace\":{\"schemes\":[\"Kit-Package\"]}}'
    exit 0
fi
cp Tests/UISnapshotTests/SnapshotTests.swift '$work/written.swift'
exit 1"
printf 'ignored/\n' >"$package/.gitignore"
mkdir -p "$package/ignored"
touch "$package/ignored/big"
CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" /bin/bash "$render" "$package" "$set_dir" "$work/out" >/dev/null
check "render-snapshots: macOS の bash でも出力先のパスを引用符なしで入れる" grep -qxF "let directory = \"$work/out\"" "$work/written.swift"
check "render-snapshots: 元のパッケージにテストを足さない" test ! -e "$package/Tests"
check "render-snapshots: 元の Package.swift を書き換えない" cmp -s "$manifest" "$package/Package.swift"
check "render-snapshots: 写しの Package.swift にテストを足す" grep -q 'name: "UISnapshotTests"' "$work"/copies/pkg-*/Package.swift
check "render-snapshots: .gitignore で外すものを写さない" test -z "$(find "$work/copies" -name big)"
check "render-snapshots: 終わったら .lock を消す" test -z "$(find "$work/copies" -name '*.lock')"

mkdir "$(echo "$work"/copies/pkg-*).lock"
CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" expect "NG 同じリポジトリを描いている途中" "render-snapshots: 描いている途中なら NG" bash "$render" "$package" "$set_dir" "$work/out"

finish
