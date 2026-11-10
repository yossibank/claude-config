#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"

section="$root/scripts/docs-section.sh"
printf '# t\n\n## a\n\nx\n\n```sh\n## not\n```\n\n## b\n\ny\n' >"$work/section.md"

expect "NG 使い方" "docs-section: 引数が無ければ NG" bash "$section"

match "docs-section: コードの中の # を見出しにしない" "$(bash "$section" "$work/section.md" | wc -l | tr -d ' ')" 3

out=$(bash "$section" "$work/section.md" a)
check "docs-section: 節の中身を出す" grep -qF x <<<"$out"
check "docs-section: 次の節は出さない" test -z "$(grep -F -e y -e '## b' <<<"$out")"

out=$(bash "$section" "$work/section.md" none)
status=$?
if [[ $status != 0 && $out == NG* ]]; then
    ok "docs-section: 無い見出しは stdout に NG"
else
    ng "docs-section: 無い見出しは stdout に NG" "$out"
fi

printf '# t\n\n> ```sh\n> ## not\n> ```\n\n## a\n' >"$work/quoted.md"
match "docs-section: 引用の中のコードの # も見出しにしない" "$(bash "$section" "$work/quoted.md" | wc -l | tr -d ' ')" 2

expect "NG 読めない" "docs-section: 無いファイルは NG" bash "$section" "$work/nothing.md"
printf '# \xff\xfe\n' >"$work/binary.md"
expect "NG 読めない" "docs-section: UTF-8 でないファイルは NG" bash "$section" "$work/binary.md"

printf '# t\n\n## 🚀 入れ方\n\nx\n\n## 📦 中身\n\ny\n' >"$work/emoji.md"
out=$(bash "$section" "$work/emoji.md" "入れ方")
match "docs-section: 頭の絵文字を外した見出しで節を出す" "$out" $'## 🚀 入れ方\n\nx'
out=$(bash "$section" "$work/emoji.md" "🚀 入れ方")
match "docs-section: 絵文字付きの見出しでも節を出す" "$out" $'## 🚀 入れ方\n\nx'
expect "候補: t / 🚀 入れ方 / 📦 中身" "docs-section: 見出しが無い時は候補を NG の行に出す" bash "$section" "$work/emoji.md" none

finish
