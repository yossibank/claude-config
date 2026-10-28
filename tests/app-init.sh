#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

replace="$root/skills/app-init/scripts/replace-placeholders.py"

make_app() {
    local app=$1 summary=$2
    mkdir -p "$app/docs" "$app/ios/__App__"
    printf 'name: __App__ / __app__ / __DisplayName__\n' >"$app/ios/__App__/__App__App.swift"
    printf '# 概要\n\n%s\n' "$summary" >"$app/docs/overview.md"
    printf '# __DisplayName__\n\n<何のアプリかを 1 文で>\n' >"$app/README.md"
}

app="$work/app"
make_app "$app" "家計を記録するアプリ。"
expect "NG 使い方" "replace-placeholders: 引数が足りなければ NG" python3 -I "$replace" "$app"
expect OK "replace-placeholders: 印を置き換える" python3 -I "$replace" "$app" Kakeibot kakeibot "カケイボ"
check "replace-placeholders: フォルダとファイルの名前の印を置き換える" test -f "$app/ios/Kakeibot/KakeibotApp.swift"
check "replace-placeholders: 中身の印を置き換える" grep -q 'name: Kakeibot / kakeibot / カケイボ' "$app/ios/Kakeibot/KakeibotApp.swift"
check "replace-placeholders: overview の 1 文を README に写す" grep -q '家計を記録するアプリ。' "$app/README.md"

draft="$work/draft"
make_app "$draft" "<何のアプリかを 1 文で>"
python3 -I "$replace" "$draft" Draft draft "下書き" >/dev/null
check "replace-placeholders: overview が書きかけなら README の印を残す" grep -q '<何のアプリかを 1 文で>' "$draft/README.md"

finish
