#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

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

finish
