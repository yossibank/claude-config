#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

export HOME="$work/home"
mkdir -p "$HOME"
scripts="$root/skills/pr-create/scripts"
repo="$work/repo"
clone_with_origin "$repo"

expect "NG 使い方" "classify: 引数が足りなければ NG" bash "$scripts/classify-diff.sh" "$repo"
expect "差分が無い" "classify: 差分が無ければ NG" bash "$scripts/classify-diff.sh" "$repo" origin/main
echo b >"$repo/日本語.md"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
if [[ $out == "docs | 1 行"* ]]; then
    ok "classify: 日本語の名前の文書だけなら docs"
else
    ng "classify: 日本語の名前の文書だけなら docs" "$out"
fi
echo 'x' >"$repo/hooks.py"
out=$(bash "$scripts/classify-diff.sh" "$repo" origin/main)
if [[ $out == small* ]]; then
    ok "classify: コードが混ざれば small"
else
    ng "classify: コードが混ざれば small" "$out"
fi
rm -f "$repo/hooks.py" "$repo/日本語.md"

expect "確認が無い" "body: 確認が無ければ本文を作らない" bash "$scripts/write-body.sh" "$repo" origin/main
bash "$scripts/run-check.sh" "$repo" true true >/dev/null
expect OK "body: 確認が通れば本文を作る" bash "$scripts/write-body.sh" "$repo" origin/main "画面"
check "body: 未検証の項目を付ける" grep -q -- '- \[ \] 画面（未検証）' "$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-body.txt)"
echo c >>"$repo/a.md"
expect "確認の後に変更がある" "body: 確認の後に変えたら止まる" bash "$scripts/write-body.sh" "$repo" origin/main
git -C "$repo" checkout -q -- a.md

finish
