#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

section="$root/scripts/docs-section.sh"
printf '# t\n\n## a\n\nx\n\n```sh\n## not\n```\n\n## b\n\ny\n' >"$work/section.md"

expect "NG 使い方" "docs-section: 引数が無ければ NG" bash "$section"

match "docs-section: コードの中の # を見出しにしない" "$(bash "$section" "$work/section.md" | wc -l | tr -d ' ')" 3

out=$(bash "$section" "$work/section.md" a)
if [[ $out == *x* && $out != *y* && $out != *"## b"* ]]; then
    ok "docs-section: 節だけを出す"
else
    ng "docs-section: 節だけを出す" "$out"
fi

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

finish
