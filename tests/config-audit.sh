#!/bin/bash
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

copy() {
    local dest="$work/$1"
    mkdir -p "$dest"
    (cd "$root" && git ls-files -z | rsync -a --from0 --files-from=- ./ "$dest/")
    git -C "$dest" init -q
    echo "$dest"
}

replace() {
    python3 -I -c 'import sys; p, a, b = sys.argv[1:]; t = open(p).read(); assert a in t, a; open(p, "w").write(t.replace(a, b))' "$@"
}

expect() {
    local dir=$1 want=$2 label=$3 out
    git -C "$dir" add -A
    out=$(python3 -I "$dir/scripts/config-audit.py")
    if [[ $want == OK ]] && [[ $out == "OK config-audit" ]] || [[ $want != OK ]] && grep -q -- "$want" <<<"$out"; then
        echo "OK ${label}"
    else
        echo "NG ${label}: 期待は「${want}」"
        echo "$out" | head -5
        fails=$((fails + 1))
    fi
}

d=$(copy clean)
expect "$d" OK "今の中身は通る"

d=$(copy ds-store)
touch "$d/skills/.DS_Store"
expect "$d" OK "追跡していない .DS_Store は数えない"

d=$(copy bash-n)
printf 'if then\n' >"$d/skills/ui-record/scripts/broken.sh"
expect "$d" "bash -n が通らない" "構文の壊れた .sh"

d=$(copy wide)
printf 'echo "x $name%s"\n' '。' >>"$d/skills/ui-record/scripts/record.sh"
expect "$d" "変数の直後に全角" "変数の直後の全角"

d=$(copy missing)
printf '\n`${CLAUDE_SKILL_DIR}/scripts/nothing.sh`\n' >>"$d/skills/ui-record/SKILL.md"
expect "$d" "参照先が無い: scripts/nothing.sh" "無いスクリプトへの参照"

d=$(copy alias)
rm -f "$d/skills/pr-create/scripts/route.sh"
expect "$d" "参照先が無い: scripts/route.sh" "別名（<S>）で書いた参照の先が無い"

d=$(copy link)
printf '\n[x](nowhere.md)\n' >>"$d/skills/ui-record/SKILL.md"
expect "$d" "リンク先が無い: nowhere.md" "壊れたリンク"

d=$(copy readme)
echo 'print(1)' >"$d/hooks/post-tool-extra.py"
expect "$d" "README の表に載っていない: hooks/post-tool-extra.py" "README に無いフック"

d=$(copy allowed)
replace "$d/skills/pr-prune/SKILL.md" 'allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/prune.sh *)' 'allowed-tools: Bash(git status *)'
expect "$d" "allowed-tools で許可していない: scripts/prune.sh" "許可していないスクリプト"

d=$(copy bash-prefix)
replace "$d/skills/pr-prune/SKILL.md" '
${CLAUDE_SKILL_DIR}/scripts/prune.sh <' '
bash ${CLAUDE_SKILL_DIR}/scripts/prune.sh <'
expect "$d" "allowed-tools で許可していない: bash scripts/prune.sh" "bash を付けた呼び方が許可と合わない"

d=$(copy ask)
replace "$d/skills/store-release/SKILL.md" 'Bash(${CLAUDE_SKILL_DIR}/scripts/screenshot.sh *)' 'Bash(${CLAUDE_SKILL_DIR}/scripts/*)'
expect "$d" "外に出す操作が allowed-tools で自動で許可されている" "外に出す操作の自動の許可"

d=$(copy unused-same-name)
cp "$d/skills/pr-create/scripts/state.sh" "$d/skills/pr-fix/scripts/state.sh"
expect "$d" "skills/pr-fix/scripts/state.sh:1 どこからも使われていない" "ほかのスキルの同じ名前で使われている扱いにしない"

d=$(copy unused-self)
printf '#!/bin/bash\necho "usage: orphan.sh"\n' >"$d/skills/ui-record/scripts/orphan.sh"
expect "$d" "orphan.sh:1 どこからも使われていない" "自分の中の名前で使われている扱いにしない"

d=$(copy no-guard)
replace "$d/skills/config-learn/scripts/collect.py" 'if __name__ == "__main__":
    main()' 'main()'
expect "$d" "collect.py:1 if __name__" "main の呼び出しを守っていない .py"

d=$(copy top-level)
printf '\nfor x in []:\n    pass\n' >>"$d/hooks/ctx-limit-read.py"
expect "$d" "読み込んだだけで処理が走る" "トップレベルで処理が走る .py"

d=$(copy exit-text)
replace "$d/skills/app-plan/scripts/search.py" 'def main():' 'def main():
    sys.exit("使い方")'
expect "$d" "sys.exit に文を渡すと" "sys.exit に文を渡す .py"

d=$(copy top-level-argv)
replace "$d/skills/app-plan/scripts/search.py" 'def main():' 'month = sys.argv[1]


def main():'
expect "$d" "search.py:.* 読み込んだだけで処理が走る" "トップレベルで引数を読む .py"

d=$(copy exit-variable)
replace "$d/skills/app-plan/scripts/search.py" 'def main():' 'def main():
    raise SystemExit(clean("x"))'
expect "$d" "sys.exit に文を渡すと" "SystemExit に式を渡す .py"

d=$(copy ng-stderr)
printf 'printf "%s %%s\\n" x >&2\n' NG >>"$d/skills/ui-record/scripts/record.sh"
expect "$d" "失敗を stderr に出している" "printf で NG を stderr に出す .sh"

d=$(copy fail-stderr)
printf 'echo "だめ" >&2\nexit 1\n' >>"$d/skills/ui-record/scripts/record.sh"
expect "$d" "失敗を stderr に出している" "NG を付けずに stderr に出して止まる .sh"

d=$(copy skill-sections)
replace "$d/skills/pr-prune/SKILL.md" '## 報告' '## 結果'
expect "$d" "## 報告 が無い" "SKILL.md に報告の節が無い"

d=$(copy skill-order)
printf '\n## 入力\n\nx\n' >>"$d/skills/ctx-handoff/SKILL.md"
expect "$d" "## 入力 は" "SKILL.md の節の順が違う"

d=$(copy agent-last)
printf '\n## 補足\n\nx\n' >>"$d/agents/explorer.md"
expect "$d" "最後の ## は「返す形」" "agents の最後の節が返す形ではない"

d=$(copy prefix-unknown)
git -C "$d" mv -q hooks/swift-format.py hooks/format-swift.py 2>/dev/null || mv "$d/hooks/swift-format.py" "$d/hooks/format-swift.py"
expect "$d" "名前の接頭語が README の表に無い: format-swift.py" "表に無い接頭語のフック"

d=$(copy prefix-place)
mv "$d/scripts/docs-section.sh" "$d/scripts/pr-section.sh"
expect "$d" "接頭語 pr- は scripts に使わない" "使う所の違う接頭語"

exit "$fails"
