#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"

find_simulator="$root/dotclaude/skills/ui-snapshot/scripts/find-simulator.sh"
fake_command xcrun "echo '{\"devices\":{\"rt\":[{\"name\":\"iPad Air\",\"udid\":\"PAD\"},{\"name\":\"iPhone 17\",\"udid\":\"PHONE\"}]}}'"
check "find-simulator: 先頭の iPhone の UDID を出す" test "$("$find_simulator")" == PHONE
fake_command xcrun "echo '{\"devices\":{\"rt\":[{\"name\":\"iPhone 17\",\"udid\":\"FIRST\"}]}}'"
check "find-simulator: iPhone が 1 台だけならその UDID を出す" test "$("$find_simulator")" == FIRST
fake_command xcrun "echo '{\"devices\":{\"old\":[{\"name\":\"iPhone 15\",\"udid\":\"OLD\"}],\"new\":[{\"name\":\"iPhone 17\",\"udid\":\"NEW\"}]}}'"
check "find-simulator: iPhone が複数あれば先頭を出す" test "$("$find_simulator")" == OLD
fake_command xcrun "echo '{\"devices\":{\"rt\":[{\"name\":\"iPad Air\",\"udid\":\"PAD\"},{\"name\":\"iPhone 17\",\"udid\":\"PHONE\"}]}}'"
fake_command xcrun "echo '{\"devices\":{}}'"
check "find-simulator: iPhone が無ければ何も出さない" test -z "$("$find_simulator")"
check "find-simulator: app-init のひな形と中身が同じ" cmp -s "$find_simulator" "$root/dotclaude/skills/app-init/templates/ios-app/scripts/find-simulator.sh"

add_target="$root/dotclaude/skills/ui-snapshot/scripts/add-target.py"
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

render="$root/dotclaude/skills/ui-snapshot/scripts/render-snapshots.sh"
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
echo \"\$*\" >'$work/arguments'
cp Tests/UISnapshotTests/SnapshotTests.swift '$work/written.swift'
exit 1"
printf 'ignored/\n' >"$package/.gitignore"
mkdir -p "$package/ignored"
touch "$package/ignored/big"
CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" /bin/bash "$render" "$package" "$set_dir" "$work/out" >/dev/null
check "render-snapshots: macOS の bash でも出力先のパスを引用符なしで入れる" grep -qxF "let directory = \"$work/out/.rendering\"" "$work/written.swift"
check "render-snapshots: テストの後に診断を集めない" grep -qF -- "-collect-test-diagnostics never" "$work/arguments"
check "render-snapshots: 元のパッケージにテストを足さない" test ! -e "$package/Tests"
check "render-snapshots: 元の Package.swift を書き換えない" cmp -s "$manifest" "$package/Package.swift"
check "render-snapshots: 写しの Package.swift にテストを足す" grep -q 'name: "UISnapshotTests"' "$work"/copies/pkg-*/Package.swift
check "render-snapshots: 写しがある" test -n "$(find "$work/copies" -name Package.swift)"
check "render-snapshots: .gitignore で外すものを写さない" test -z "$(find "$work/copies" -name big)"
check "render-snapshots: 終わったら .lock を消す" test -z "$(find "$work/copies" -name '*.lock')"

mkdir "$(echo "$work"/copies/pkg-*).lock"
CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" expect "NG 同じリポジトリを描いている途中" "render-snapshots: 描いている途中なら NG" bash "$render" "$package" "$set_dir" "$work/out"

printf 'Co"re\nSnap:pk\\g\n' >"$work/escape.txt"
printf 'let package = Package(\n    targets: [\n    ]\n)\n' >"$work/Escape.swift"
python3 -I "$add_target" "$work/Escape.swift" "$work/escape.txt"
check "add-target: 名前の引用符とバックスラッシュを逃がす" grep -qF '"Co\"re"' "$work/Escape.swift"
check "add-target: 製品とパッケージの名前も逃がす" grep -qF '.product(name: "Snap", package: "pk\\g")' "$work/Escape.swift"

lock=$(echo "$work"/copies/pkg-*.lock)
touch "$work/out/old.png"
echo 999999 >"$lock/pid"
CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" expect "NG テストが通らなかった（xcodebuild: 1、ログ: " "render-snapshots: 止まった実行のロックは外して、描き直す。失敗の NG にログの場所を出す" bash "$render" "$package" "$set_dir" "$work/out"
check "render-snapshots: 描けなかった時は、前の PNG を消さない" test -e "$work/out/old.png"
check "render-snapshots: 全ログを残す" test -f "${lock%.lock}/.build/ui-snapshot.log"


# 描けた時の道: xcodebuild が PNG を書いたことにする
fake_command xcodebuild "
if [[ \$1 == -list ]]; then
    echo '{\"workspace\":{\"schemes\":[\"Kit-Package\"]}}'
    exit 0
fi
dir=\$(sed -n 's/^let directory = \"\\(.*\\)\"\$/\\1/p' Tests/UISnapshotTests/SnapshotTests.swift)
printf png >\"\$dir/home-light.png\"
printf png >\"\$dir/home-dark.png\"
exit 0"
rm -rf "$work/copies/"*.lock
out=$(CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" bash "$render" "$package" "$set_dir" "$work/out" 2>&1)
check "render-snapshots: 描けたら PNG の一覧を OK 相当で出す" grep -qxF "$work/out/home-dark.png" <<<"$out"
check "render-snapshots: 描けたら出力先へ PNG を移す" test -s "$work/out/home-light.png"
check "render-snapshots: 描けたら前の PNG を入れ替える" test ! -e "$work/out/old.png"
check "render-snapshots: 描いた後に途中の置き場を残さない" test ! -e "$work/out/.rendering"

fake_command xcodebuild "
if [[ \$1 == -list ]]; then
    echo '{\"workspace\":{\"schemes\":[\"Kit-Package\"]}}'
    exit 0
fi
exit 0"
printf png >"$work/out/keep.png"
CC_UI_DEVICE=MINE CC_UI_WORK_DIR="$work/copies" expect "NG PNG が描かれなかった" "render-snapshots: テストが通っても PNG が無ければ NG" bash "$render" "$package" "$set_dir" "$work/out"
check "render-snapshots: PNG が描かれなかった時は、前の PNG を消さない" test -s "$work/out/keep.png"

finish
