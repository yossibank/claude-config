#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/support/assert.sh"

icons="$root/scripts/docs-tech-icons.py"
mkdir -p "$work/icons"
printf '<svg viewBox="0 0 24 24"><title>A</title><path d="M0 0h24v24H0z"/></svg>' >"$work/icons/swift.svg"
printf '<svg viewBox="0 0 24 24"><title>B</title></svg>' >"$work/icons/empty.svg"

expect "NG 使い方" "docs-tech-icons: 引数が無ければ NG" python3 -I "$icons"
expect "NG 形が違う" "docs-tech-icons: 色が 6 桁でなければ NG" python3 -I "$icons" --icons "$work/icons" "$work/out.svg" "swift:F05:Swift"
expect "NG アイコンが無い" "docs-tech-icons: 無い slug は NG" python3 -I "$icons" --icons "$work/icons" "$work/out.svg" "kotlin:7F52FF:Kotlin"
expect "NG アイコンに path が無い" "docs-tech-icons: path の無いアイコンは NG" python3 -I "$icons" --icons "$work/icons" "$work/out.svg" "empty:000000:E"

expect OK "docs-tech-icons: アイコンを並べた SVG を書く" python3 -I "$icons" --icons "$work/icons" "$work/out/tech.svg" "swift:F05138:Swift:6" "swift:0A84FF:SwiftUI"
svg=$(cat "$work/out/tech.svg")
match "docs-tech-icons: 並べた数だけ幅を取る" "$svg" '*width="224"*'
match "docs-tech-icons: 版のある時は高さを足す" "$svg" '*height="148"*'
match "docs-tech-icons: 色と名前と版を入れる" "$svg" '*#F05138*Swift*>6<*#0A84FF*SwiftUI*'
match "docs-tech-icons: アイコンの path を写す" "$svg" '*<path d="M0 0h24v24H0z"/>*'

python3 -I "$icons" --icons "$work/icons" "$work/plain.svg" "swift:000000:A&B" >/dev/null
match "docs-tech-icons: 版が無ければ低くし、名前を XML に合わせる" "$(cat "$work/plain.svg")" '*height="128"*A&amp;B*'

finish
