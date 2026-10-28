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

exit "$fails"
