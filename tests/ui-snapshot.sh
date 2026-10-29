#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$root/lib/simulator.sh"

fake_command xcrun "echo '{\"devices\":{\"rt\":[{\"name\":\"iPad Air\",\"udid\":\"PAD\"},{\"name\":\"iPhone 17\",\"udid\":\"PHONE\"}]}}'"
check "pick_iphone: 先頭の iPhone の UDID を出す" test "$(pick_iphone)" == PHONE
check "pick_iphone: CC_UI_DEVICE があればそれを出す" test "$(CC_UI_DEVICE=MINE pick_iphone)" == MINE
fake_command xcrun "echo '{\"devices\":{}}'"
check "pick_iphone: iPhone が無ければ何も出さない" test -z "$(pick_iphone)"

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
expect "NG 出力先がパッケージの中にある" "render-snapshots: 出力先がパッケージの中なら NG" bash "$render" "$package" "$set_dir" "$package/out"
mkdir -p "$work/busy"
touch "$work/busy/keep.txt"
expect "NG 出力先が空でなく" "render-snapshots: 出力先に別のファイルがあれば NG" bash "$render" "$package" "$set_dir" "$work/busy"
mkdir -p "$package/Tests/UISnapshotTests"
expect "NG 前の回の後片付けが済んでいない" "render-snapshots: 前の回のテストが残っていれば NG" bash "$render" "$package" "$set_dir" "$work/out"

finish
