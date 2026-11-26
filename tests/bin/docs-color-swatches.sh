#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"

swatches="$root/bin/docs-color-swatches.py"

expect "NG 使い方" "docs-color-swatches: 引数が無ければ NG" python3 -I "$swatches"
expect "NG 使い方" "docs-color-swatches: 色が無ければ NG" python3 -I "$swatches" "$work/out.svg"
expect "NG 形が違う" "docs-color-swatches: 色が 6 桁でなければ NG" python3 -I "$swatches" "$work/out.svg" "背景:FFF"
expect "NG 形が違う" "docs-color-swatches: 名前が無ければ NG" python3 -I "$swatches" "$work/out.svg" ":FFFFFF"

expect "OK" "docs-color-swatches: ライトだけの色見本を書く" python3 -I "$swatches" "$work/out/light.svg" "背景:ffffff" "A&B:1C1C1E"
svg=$(cat "$work/out/light.svg")
match "docs-color-swatches: 値を大文字にして四角と値を入れる" "$svg" '*fill="#FFFFFF"*>#FFFFFF<*fill="#1C1C1E"*'
match "docs-color-swatches: 名前を XML に合わせる" "$svg" '*>A&amp;B<*'
check "docs-color-swatches: ライトだけなら列の見出しを置かない" bash -c '! grep -q "ダーク" "$1"' _ "$work/out/light.svg"

expect "OK" "docs-color-swatches: ライトとダークの 2 列を書く" python3 -I "$swatches" "$work/out/both.svg" "背景:FFFFFF:1C1C1E" "文字:1C1C1E"
svg=$(cat "$work/out/both.svg")
match "docs-color-swatches: 2 列の見出しを置く" "$svg" '*>ライト<*>ダーク<*'
match "docs-color-swatches: ダークの値を同じ行に並べる" "$svg" '*>#FFFFFF<*>#1C1C1E<*>文字<*>#1C1C1E<*'
light_width=$(grep -o 'width="[0-9]*"' "$work/out/light.svg" | head -1)
both_width=$(grep -o 'width="[0-9]*"' "$work/out/both.svg" | head -1)
check "docs-color-swatches: 2 列の方が幅を取る" test "$light_width" != "$both_width"

finish
