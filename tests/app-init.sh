#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

replace="$root/skills/app-init/scripts/replace-placeholders.py"
overview="$root/skills/app-plan/templates/overview.md"
readme="$root/skills/app-init/templates/ios-app/README.md"
placeholder='<何のアプリかを 1 文で。誰の、どの不満を解くか>'

make_app() {
    local app=$1 summary=$2
    mkdir -p "$app/docs" "$app/ios/__App__"
    printf 'name: __App__ / __app__ / __DisplayName__\n' >"$app/ios/__App__/__App__App.swift"
    python3 -I -c 'import sys; src, dst, a, b = sys.argv[1:]; t = open(src).read(); assert a in t, a; open(dst, "w").write(t.replace(a, b))' \
        "$overview" "$app/docs/overview.md" "$placeholder" "$summary"
    cp "$readme" "$app/README.md"
}

app="$work/app"
make_app "$app" "家計を記録するアプリ。続けられない人の不満を解く。"
expect "NG 使い方" "replace-placeholders: 引数が足りなければ NG" python3 -I "$replace" "$app"
expect OK "replace-placeholders: 印を置き換える" python3 -I "$replace" "$app" Kakeibot kakeibot "カケイボ"
check "replace-placeholders: フォルダとファイルの名前の印を置き換える" test -f "$app/ios/Kakeibot/KakeibotApp.swift"
check "replace-placeholders: 中身の印を置き換える" grep -q 'name: Kakeibot / kakeibot / カケイボ' "$app/ios/Kakeibot/KakeibotApp.swift"
check "replace-placeholders: ひな形の overview の最初の 1 文を README に写す" grep -qx '家計を記録するアプリ。' "$app/README.md"
check "replace-placeholders: 冒頭の NOTE を README に写さない" test -z "$(grep -F '[!NOTE]' "$app/README.md")"

draft="$work/draft"
make_app "$draft" "$placeholder"
python3 -I "$replace" "$draft" Draft draft "下書き" >/dev/null
check "replace-placeholders: overview が書きかけなら README の印を残す" grep -q '<何のアプリかを 1 文で>' "$draft/README.md"

finish
