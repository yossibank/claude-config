#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

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

audit_matches() {
    local want=$1 out=$2
    if [[ $want == OK ]]; then
        [[ $out == "OK config-audit" ]]
    else
        grep -q -- "$want" <<<"$out"
    fi
}

expect_audit() {
    local dir=$1 want=$2 label=$3 out
    git -C "$dir" add -A
    out=$(python3 -I "$dir/scripts/config-audit.py")
    if audit_matches "$want" "$out"; then
        ok "$label"
    else
        ng "${label}: 期待は「${want}」" "$out"
    fi
}

d=$(copy clean)
expect_audit "$d" OK "今の中身は通る"

d=$(copy ds-store)
touch "$d/skills/.DS_Store"
expect_audit "$d" OK "追跡していない .DS_Store は数えない"

d=$(copy bash-n)
printf 'if then\n' >"$d/skills/ui-record/scripts/broken.sh"
expect_audit "$d" "bash -n が通らない" "構文の壊れた .sh"

d=$(copy wide)
printf 'echo "x $name%s"\n' '。' >>"$d/skills/ui-record/scripts/record-video.sh"
expect_audit "$d" "変数の直後に全角" "変数の直後の全角"

d=$(copy missing)
printf '\n`${CLAUDE_SKILL_DIR}/scripts/nothing.sh`\n' >>"$d/skills/ui-record/SKILL.md"
expect_audit "$d" "参照先が無い: scripts/nothing.sh" "無いスクリプトへの参照"

d=$(copy alias)
rm -f "$d/skills/pr-create/scripts/route-pr.sh"
expect_audit "$d" "参照先が無い: scripts/route-pr.sh" "別名（<S>）で書いた参照の先が無い"

d=$(copy link)
printf '\n[x](nowhere.md)\n' >>"$d/skills/ui-record/SKILL.md"
expect_audit "$d" "リンク先が無い: nowhere.md" "壊れたリンク"

d=$(copy readme)
echo 'print(1)' >"$d/hooks/post-tool-extra.py"
expect_audit "$d" "README の表に載っていない: hooks/post-tool-extra.py" "README に無いフック"

d=$(copy allowed)
replace "$d/skills/pr-prune/SKILL.md" 'allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh *)' 'allowed-tools: Bash(git status *)'
expect_audit "$d" "allowed-tools で許可していない: scripts/prune-merged.sh" "許可していないスクリプト"

d=$(copy bash-prefix)
replace "$d/skills/pr-prune/SKILL.md" '
${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh <' '
bash ${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh <'
expect_audit "$d" "allowed-tools で許可していない: bash scripts/prune-merged.sh" "bash を付けた呼び方が許可と合わない"

d=$(copy ask)
replace "$d/skills/store-release/SKILL.md" 'Bash(${CLAUDE_SKILL_DIR}/scripts/take-screenshot.sh *)' 'Bash(${CLAUDE_SKILL_DIR}/scripts/*)'
expect_audit "$d" "外に出す操作が allowed-tools で自動で許可されている" "外に出す操作の自動の許可"

d=$(copy unused-same-name)
cp "$d/skills/pr-create/scripts/hash-state.sh" "$d/skills/pr-fix/scripts/hash-state.sh"
expect_audit "$d" "skills/pr-fix/scripts/hash-state.sh:1 どこからも使われていない" "ほかのスキルの同じ名前で使われている扱いにしない"

d=$(copy unused-self)
printf '#!/bin/bash\necho "usage: orphan.sh"\n' >"$d/skills/ui-record/scripts/orphan.sh"
expect_audit "$d" "orphan.sh:1 どこからも使われていない" "自分の中の名前で使われている扱いにしない"

d=$(copy no-guard)
replace "$d/skills/config-learn/scripts/collect-corrections.py" 'if __name__ == "__main__":
    main()' 'main()'
expect_audit "$d" "collect-corrections.py:1 if __name__" "main の呼び出しを守っていない .py"

d=$(copy top-level)
printf '\nfor x in []:\n    pass\n' >>"$d/hooks/ctx-limit-read.py"
expect_audit "$d" "読み込んだだけで処理が走る" "トップレベルで処理が走る .py"

d=$(copy exit-text)
replace "$d/skills/app-plan/scripts/search-apps.py" 'def main():' 'def main():
    sys.exit("使い方")'
expect_audit "$d" "sys.exit に文を渡すと" "sys.exit に文を渡す .py"

d=$(copy top-level-argv)
replace "$d/skills/app-plan/scripts/search-apps.py" 'def main():' 'month = sys.argv[1]


def main():'
expect_audit "$d" "search-apps.py:.* 読み込んだだけで処理が走る" "トップレベルで引数を読む .py"

d=$(copy exit-variable)
replace "$d/skills/app-plan/scripts/search-apps.py" 'def main():' 'def main():
    raise SystemExit(clean("x"))'
expect_audit "$d" "sys.exit に文を渡すと" "SystemExit に式を渡す .py"

d=$(copy ng-stderr)
printf 'printf "%s %%s\\n" x >&2\n' NG >>"$d/skills/ui-record/scripts/record-video.sh"
expect_audit "$d" "失敗を stderr に出している" "printf で NG を stderr に出す .sh"

d=$(copy fail-stderr)
printf 'echo "だめ" >&2\nexit 1\n' >>"$d/skills/ui-record/scripts/record-video.sh"
expect_audit "$d" "失敗を stderr に出している" "NG を付けずに stderr に出して止まる .sh"

d=$(copy skill-sections)
replace "$d/skills/pr-prune/SKILL.md" '## 報告' '## 結果'
expect_audit "$d" "## 報告 が無い" "SKILL.md に報告の節が無い"

d=$(copy skill-order)
printf '\n## 入力\n\nx\n' >>"$d/skills/ctx-handoff/SKILL.md"
expect_audit "$d" "## 入力 は" "SKILL.md の節の順が違う"

d=$(copy skill-order-fence)
printf '\n~~~text\n```swift\n~~~\n\n## 入力\n\nx\n' >>"$d/skills/ctx-handoff/SKILL.md"
expect_audit "$d" "## 入力 は" "チルダの囲みの中のバッククォートで、囲みの外の見出しを見落とさない"

d=$(copy agent-last)
printf '\n## 補足\n\nx\n' >>"$d/agents/explorer.md"
expect_audit "$d" "最後の ## は「返す形」" "agents の最後の節が返す形ではない"

d=$(copy prefix-unknown)
git -C "$d" mv -q hooks/swift-format.py hooks/format-swift.py 2>/dev/null || mv "$d/hooks/swift-format.py" "$d/hooks/format-swift.py"
expect_audit "$d" "名前の接頭語が README の表に無い: format-swift.py" "表に無い接頭語のフック"

d=$(copy prefix-place)
mv "$d/scripts/docs-section.sh" "$d/scripts/pr-section.sh"
expect_audit "$d" "接頭語 pr- は scripts に使わない" "使う所の違う接頭語"

d=$(copy verb-ok)
replace "$d/README.md" '| `record`・`render`・' '| `glue`・`record`・`render`・'
mv "$d/skills/ui-record/scripts/tile-frames.sh" "$d/skills/ui-record/scripts/glue-frames.sh"
replace "$d/skills/ui-record/SKILL.md" 'tile-frames.sh' 'glue-frames.sh'
expect_audit "$d" OK "README の動詞の表にある動詞で始まるスクリプト"

d=$(copy verb-ng)
mv "$d/skills/ui-record/scripts/tile-frames.sh" "$d/skills/ui-record/scripts/frames-tile.sh"
expect_audit "$d" "頭の動詞が README の表に無い: frames" "動詞で始まらないスクリプト"

d=$(copy path-ok)
printf '\n`hooks/<名前>.py` と `scripts/verify.sh` を読む。\n' >>"$d/docs/architecture-ios.md"
expect_audit "$d" OK "印の入ったパスと、アプリのひな形にあるパス"

d=$(copy path-ng)
printf '\n`hooks/nothing.py` を読む。\n' >>"$d/docs/architecture-ios.md"
expect_audit "$d" "参照先が無い: hooks/nothing.py" "無いファイルへのパス"

d=$(copy template-script-ng)
replace "$d/skills/app-init/templates/ios-app/Makefile" 'scripts/render-snapshots.sh' 'scripts/render.sh'
expect_audit "$d" "claude-config の参照先が無い: skills/ui-snapshot/scripts/render.sh" "ひな形の Makefile が無いスクリプトを呼ぶ"

d=$(copy skill-dir-ok)
printf '\n`${CLAUDE_SKILL_DIR}/templates/<セット>/` を写す。\n' >>"$d/skills/ui-snapshot/SKILL.md"
expect_audit "$d" OK "印の入った CLAUDE_SKILL_DIR の参照"

d=$(copy skill-dir-ng)
printf '\n`${CLAUDE_SKILL_DIR}/templates/nothing/` を写す。\n' >>"$d/skills/ui-snapshot/SKILL.md"
expect_audit "$d" "参照先が無い: templates/nothing" "無いひな形への CLAUDE_SKILL_DIR の参照"

d=$(copy agent-tools-ok)
replace "$d/agents/implementer.md" 'model: sonnet
' 'model: sonnet
tools: Read, Edit
'
expect_audit "$d" OK "書き換えるエージェントは Edit を持てる"

d=$(copy agent-tools-ng)
replace "$d/agents/explorer.md" 'tools: Read, Grep, Glob, Bash
' ''
expect_audit "$d" "書き換えないエージェントは tools を書き" "書き換えないエージェントが全部の道具を持つ"

d=$(copy agent-tools-multi-edit)
replace "$d/agents/explorer.md" 'tools: Read, Grep, Glob, Bash' 'tools: Read, Grep, Glob, Bash, MultiEdit'
expect_audit "$d" "書き換えないエージェントは tools を書き" "書き換えないエージェントが MultiEdit を持つ"

d=$(copy agent-tools-notebook-edit)
replace "$d/agents/reviewer.md" 'tools: Read, Grep, Glob, Bash' 'tools: Read, Grep, Glob, Bash, NotebookEdit'
expect_audit "$d" "書き換えないエージェントは tools を書き" "書き換えないエージェントが NotebookEdit を持つ"

d=$(copy claude-template-ok)
replace "$d/skills/app-init/templates/ios-app/CLAUDE.md" '## 構成
' '## コードの書き方
'
expect_audit "$d" OK "ひな形の CLAUDE.md の節が決まった順"

d=$(copy claude-template-ng)
replace "$d/skills/app-init/templates/ios-app/CLAUDE.md" '## 作業の進め方' '## 進め方'
expect_audit "$d" "CLAUDE.md の ## は" "ひな形の CLAUDE.md の節の順が違う"

d=$(copy template-link-ok)
printf '\n[r](docs/roadmap.md)\n' >>"$d/skills/app-init/templates/ios-app/README.md"
expect_audit "$d" OK "ひな形の中で、写した後に辿れるリンク"

d=$(copy template-link-ng)
printf '\n[x](docs/nothing.md)\n' >>"$d/skills/app-init/templates/ios-app/README.md"
expect_audit "$d" "リンク先が無い: docs/nothing.md" "ひな形の中の壊れたリンク"

finish
