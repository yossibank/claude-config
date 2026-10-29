#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

layout="$root/skills/docs-polish/scripts/check-layout.py"
mkdir -p "$work/repo/docs"
printf '# t\n\n## 長い節\n\nあ。\nい。\nう。\nえ。\n\n## 表の節\n\nお。\nか。\nき。\nく。\n\n| a | b |\n| --- | --- |\n\n## 短い節\n\nけ。\n\n```sh\nx\nx\nx\nx\n```\n' >"$work/repo/README.md"
printf '# d\n\n![a](a)\n![b](b)\n![c](c)\n![d](d)\n\n## 図の節\n\nあ。\nい。\nう。\nえ。\n\n```mermaid\nflowchart LR\n```\n' >"$work/repo/docs/a.md"
echo '# memo' >"$work/repo/memo.md"

expect "NG 使い方" "check-layout: 引数が無ければ NG" python3 -I "$layout"
expect "NG ファイルもフォルダも無い" "check-layout: 無いパスは NG" python3 -I "$layout" "$work/none"
out=$(python3 -I "$layout" "$work/repo")
status=$?
check "check-layout: 当たる節があれば終了コード 1" test "$status" -eq 1
check "check-layout: 文だけが続く節を NG にする" grep -qF "README.md:3 長い節: 文が 4 行続き" <<<"$out"
check "check-layout: 表のある節は通す" bash -c '! grep -q "表の節" <<<"$1"' _ "$out"
check "check-layout: コードの囲みの中は文に数えない" bash -c '! grep -q "短い節" <<<"$1"' _ "$out"
check "check-layout: 図のある文書は OK" grep -qF "OK $work/repo/docs/a.md" <<<"$out"
check "check-layout: フォルダでは README・docs・spec の外を見ない" bash -c '! grep -q "memo.md" <<<"$1"' _ "$out"

finish
