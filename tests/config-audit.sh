#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/support/assert.sh"

base="$work/base"

prepare_base() {
    mkdir -p "$base" &&
        (cd "$root" && git ls-files -z -co --exclude-standard | rsync -a --from0 --files-from=- ./ "$base/") &&
        git -C "$base" init -q &&
        git -C "$base" add -A &&
        git -C "$base" -c user.name=t -c user.email=t@t commit -q -m base
}

if ! prepare_base; then
    ng "config-audit: 検査する写しを作れなかった"
    finish
fi

copy() {
    git -C "$base" reset -q --hard
    git -C "$base" clean -fdxq
    echo "$base"
}

replace() {
    replace_text "$1" "$1" "$2" "$3"
}

# 台帳の「残っている改善」の見出しの直後に行を足す。今の台帳の行に頼らずに場所の列を試す
add_ledger_row() {
    local file=$1 tmp
    tmp=$(mktemp)
    ROW=$2 awk '{ print } $0 == "## 📝 残っている改善" { print ""; print ENVIRON["ROW"] }' "$file" >|"$tmp" && mv "$tmp" "$file"
}

audit_matches() {
    local want=$1 out=$2
    if [[ $want == OK ]]; then
        [[ $out == "OK config-audit" ]]
    else
        grep -qF -- "$want" <<<"$out"
    fi
}

expect_audit() {
    local dir=$1 want=$2 label=$3 out status=0
    git -C "$dir" add -A
    out=$(python3 -I "$dir/scripts/config-audit.py") || status=$?
    if [[ $want == OK && $status != 0 ]] || [[ $want != OK && $status != 1 ]]; then
        ng "config-audit: ${label}: 終了コードが ${status}（OK は 0、NG は 1）" "$out"
    elif audit_matches "$want" "$out"; then
        ok "config-audit: $label"
    else
        ng "config-audit: ${label}: 期待は「${want}」" "$out"
    fi
}

d=$(copy clean)
expect_audit "$d" OK "今の中身は通る"

d=$(copy ds-store)
touch "$d/dotclaude/skills/.DS_Store"
expect_audit "$d" OK "追跡していない .DS_Store は数えない"

d=$(copy bash-n)
printf 'if then\n' >"$d/dotclaude/skills/ui-record/scripts/broken.sh"
expect_audit "$d" "bash -n が通らない" "構文の壊れた .sh"

d=$(copy wide)
printf 'echo "x $name%s"\n' '。' >>"$d/dotclaude/skills/ui-record/scripts/record-video.sh"
expect_audit "$d" "変数の直後に全角" "変数の直後の全角"

d=$(copy fenced-link)
printf '\n```text\n[x](nothing.md)\n```\n' >>"$d/docs/config/testing.md"
expect_audit "$d" OK "コードの囲みの中のリンクは見ない"

d=$(copy broken-link)
printf '\n[x](nothing.md)\n' >>"$d/docs/config/testing.md"
expect_audit "$d" "リンク先が無い: nothing.md" "文中のリンク先が無い"

d=$(copy missing)
printf '\n`${CLAUDE_SKILL_DIR}/scripts/nothing.sh`\n' >>"$d/dotclaude/skills/ui-record/SKILL.md"
expect_audit "$d" "参照先が無い: scripts/nothing.sh" "無いスクリプトへの参照"

d=$(copy alias)
rm -f "$d/dotclaude/skills/pr-create/scripts/route-pr.sh"
expect_audit "$d" "参照先が無い: scripts/route-pr.sh" "別名（<S>）で書いた参照の先が無い"

d=$(copy link)
printf '\n[x](nowhere.md)\n' >>"$d/dotclaude/skills/ui-record/SKILL.md"
expect_audit "$d" "リンク先が無い: nowhere.md" "壊れたリンク"

d=$(copy anchor)
replace "$d/docs/config/development.md" '[接頭語の表](#接頭語の表)' '[接頭語の表](#無い表)'
expect_audit "$d" "リンク先の見出しが無い: #無い表" "壊れた見出しへのリンク"

d=$(copy flow)
replace "$d/docs/config/skills.md" 'docsPolish["docs-polish"]' 'polish["文書の手入れ"]'
expect_audit "$d" "スキルを使う順の図に載っていない: docs-polish" "skills.md のスキルの図に無いスキル"

d=$(copy terms)
printf '\n作業場所で確かめる。\n' >>"$d/dotclaude/skills/ui-record/SKILL.md"
expect_audit "$d" "「作業場所」ではなく「ワークツリー」と書く" "そろえる語の表の使わない語"

d=$(copy steps)
replace "$d/dotclaude/skills/ctx-report/SKILL.md" '1. `count-tokens.py` で表を出す。' '`count-tokens.py` で表を出す。'
expect_audit "$d" "dotclaude/skills/ctx-report/SKILL.md:1 「手順」は番号付きの箇条書きで書く" "番号の無い手順"

d=$(copy header)
replace "$d/dotclaude/skills/ui-record/scripts/tile-frames.sh" 'set -euo pipefail' 'set -uo pipefail'
expect_audit "$d" "2 行目を set -euo pipefail にする" "-e の無いスキルのスクリプト"

d=$(copy inline-python)
printf "python3 -I -c 'print(1)'\n" >>"$d/dotclaude/skills/ui-record/scripts/tile-frames.sh"
expect_audit "$d" "bash の中に Python を書かない" "bash の中の Python"

d=$(copy worktrees)
printf 'echo "$HOME/.claude/worktrees"\n' >>"$d/dotclaude/skills/ui-record/scripts/tile-frames.sh"
expect_audit "$d" "ワークツリーの置き場所は lib の" "ワークツリーの置き場所の直書き"

d=$(copy assert)
printf '\n\ndef broken():\n    assert True\n' >>"$d/lib/dates.py"
expect_audit "$d" "assert は python -O で消え" "assert"

d=$(copy matcher)
replace "$d/dotclaude/settings.json" '"Edit|Write"' '"Edit"'
expect_audit "$d" "編集の matcher は hook_io の FILE_EDIT_TOOLS と同じ" "編集の道具が欠けた matcher"

d=$(copy settings-no-runner)
replace "$d/dotclaude/settings.json" 'hooks/run.sh\" ctx-limit-read' 'hooks/ctx-limit-read.py\"'
expect_audit "$d" "フックを hooks/run.sh で呼んでいない" "run.sh を通さないフック"

d=$(copy settings-missing-hook)
replace "$d/dotclaude/settings.json" 'hooks/run.sh\" ctx-limit-read' 'hooks/run.sh\" nothing-here'
expect_audit "$d" "フックのファイルが無い: hooks/nothing-here.py" "settings にあるフックのファイルが無い"

d=$(copy matcher-extra)
replace "$d/dotclaude/settings.json" '"Edit|Write"' '"Edit|Write|Bash"'
expect_audit "$d" "編集の matcher は hook_io の FILE_EDIT_TOOLS と同じ" "編集の道具に別の道具が混ざる matcher"

d=$(copy skill-name)
replace "$d/dotclaude/skills/pr-prune/SKILL.md" 'name: pr-prune' 'name: pr-other'
expect_audit "$d" "dotclaude/skills/pr-prune/SKILL.md:2 name がフォルダ名 pr-prune と違う: pr-other" "フォルダ名と違う name"

d=$(copy skill-description-end)
replace "$d/dotclaude/skills/pr-prune/SKILL.md" '使う。
argument-hint' '使う
argument-hint'
expect_audit "$d" "dotclaude/skills/pr-prune/SKILL.md:3 description を「。」で終える" "「。」で終わらない description"

d=$(copy skill-description-long)
replace "$d/dotclaude/skills/pr-prune/SKILL.md" 'マージされた PR の反映と' "$(printf 'あ%.0s' $(seq 130))"
expect_audit "$d" "dotclaude/skills/pr-prune/SKILL.md:3 description が 120 字を超えている" "長すぎる description"

d=$(copy agent-name)
replace "$d/dotclaude/agents/tester.md" 'name: tester' 'name: other'
expect_audit "$d" "dotclaude/agents/tester.md:2 name がファイル名 tester と違う: other" "ファイル名と違うエージェントの name"

d=$(copy agent-model)
replace "$d/dotclaude/agents/tester.md" 'model: sonnet
' ''
expect_audit "$d" "dotclaude/agents/tester.md:1 model が無い" "model の無いエージェント"

d=$(copy rule-paths)
replace "$d/dotclaude/rules/swift-core.md" 'paths:' 'globs:'
expect_audit "$d" "dotclaude/rules/swift-core.md:1 frontmatter に paths が無い" "paths の無い rules"

d=$(copy readme)
echo 'print(1)' >"$d/dotclaude/hooks/post-tool-extra.py"
expect_audit "$d" "部品の文書の表に載っていない: dotclaude/hooks/post-tool-extra.py" "部品の文書に無いフック"

d=$(copy test-missing-hook)
rm -f "$d/tests/swift-format.sh"
expect_audit "$d" "dotclaude/hooks/swift-format.py:1 テストが無い: tests/swift-format.sh" "テストの無いフック"

d=$(copy test-missing-script)
rm -f "$d/tests/config-install.sh"
expect_audit "$d" "scripts/config-install.sh:1 テストが無い: tests/config-install.sh" "テストの無い scripts のファイル"

d=$(copy test-missing-skill)
rm -f "$d/tests/ui-record.sh"
expect_audit "$d" "dotclaude/skills/ui-record/SKILL.md:1 テストが無い: tests/ui-record.sh" "テストの無い、スクリプトを持つスキル"

d=$(copy test-orphan)
printf '#!/bin/bash\n' >"$d/tests/nothing.sh"
expect_audit "$d" "tests/nothing.sh:1 テストの対象が無い" "対象の無いテスト"

d=$(copy test-orphan-run)
printf '#!/bin/bash\n' >"$d/tests/run.sh"
expect_audit "$d" "tests/run.sh:1 テストの対象が無い" "hooks/run.sh はテストの対象にしない"

d=$(copy allowed)
replace "$d/dotclaude/skills/pr-prune/SKILL.md" 'allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh *)' 'allowed-tools: Bash(git status *)'
expect_audit "$d" "allowed-tools で許可していない: scripts/prune-merged.sh" "許可していないスクリプト"

d=$(copy bash-prefix)
replace "$d/dotclaude/skills/pr-prune/SKILL.md" '
${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh <' '
bash ${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh <'
expect_audit "$d" "allowed-tools で許可していない: bash scripts/prune-merged.sh" "bash を付けた呼び方が許可と合わない"

d=$(copy ask)
replace "$d/dotclaude/skills/store-release/SKILL.md" 'Bash(${CLAUDE_SKILL_DIR}/scripts/take-screenshot.sh *)' 'Bash(${CLAUDE_SKILL_DIR}/scripts/*)'
expect_audit "$d" "外に出す操作が allowed-tools で自動で許可されている" "外に出す操作の自動の許可"

d=$(copy unused-same-name)
cp "$d/dotclaude/skills/pr-create/scripts/hash-state.sh" "$d/dotclaude/skills/pr-fix/scripts/hash-state.sh"
expect_audit "$d" "dotclaude/skills/pr-fix/scripts/hash-state.sh:1 どこからも使われていない" "ほかのスキルの同じ名前で使われている扱いにしない"

d=$(copy unused-self)
printf '#!/bin/bash\necho "usage: orphan.sh"\n' >"$d/dotclaude/skills/ui-record/scripts/orphan.sh"
expect_audit "$d" "orphan.sh:1 どこからも使われていない" "自分の中の名前で使われている扱いにしない"

d=$(copy no-guard)
replace "$d/dotclaude/skills/config-learn/scripts/collect-corrections.py" 'if __name__ == "__main__":
    run_main(main)' 'run_main(main)'
expect_audit "$d" "collect-corrections.py:1 if __name__" "main の呼び出しを守っていない .py"

d=$(copy top-level)
printf '\nfor x in []:\n    pass\n' >>"$d/dotclaude/hooks/ctx-limit-read.py"
expect_audit "$d" "読み込んだだけで処理が走る" "トップレベルで処理が走る .py"

d=$(copy exit-text)
replace "$d/dotclaude/skills/app-plan/scripts/search-apps.py" 'def main():' 'def main():
    sys.exit("使い方")'
expect_audit "$d" "sys.exit に文を渡すと" "sys.exit に文を渡す .py"

d=$(copy top-level-argv)
replace "$d/dotclaude/skills/app-plan/scripts/search-apps.py" 'def main():' 'month = sys.argv[1]


def main():'
expect_audit "$d" "search-apps.py:11 読み込んだだけで処理が走る" "トップレベルで引数を読む .py"

d=$(copy exit-variable)
replace "$d/dotclaude/skills/app-plan/scripts/search-apps.py" 'def main():' 'def main():
    raise SystemExit(clean("x"))'
expect_audit "$d" "sys.exit に文を渡すと" "SystemExit に式を渡す .py"

d=$(copy hook-unwrapped)
replace "$d/dotclaude/hooks/ctx-limit-read.py" 'run_hook("ctx-limit-read", main)' 'main()'
expect_audit "$d" "dotclaude/hooks/ctx-limit-read.py:1 main を run_gate か run_hook で包む" "run_hook で包まないフック"

d=$(copy script-unwrapped)
replace "$d/scripts/docs-tech-icons.py" 'run_main(main)' 'main()'
expect_audit "$d" "scripts/docs-tech-icons.py:1 main を run_main で包む" "run_main で包まない .py"

d=$(copy lib-unwrapped)
replace "$d/lib/docs_section.py" 'run_main(main)' 'main()'
expect_audit "$d" "lib/docs_section.py:1 main を run_main で包む" "run_main で包まない lib の .py"

d=$(copy script-body)
printf "." >"$d/scripts/docs-section.jq"
expect_audit "$d" "scripts/docs-section.jq:1 scripts/ には入口だけを置く。同じ名前の中身は lib/ に移す: docs-section" "scripts に置いた中身"

d=$(copy test-inline-python)
printf "python3 -I -c 'print(1)'\n" >>"$d/tests/ctx-limit-read.sh"
expect_audit "$d" "tests/ctx-limit-read.sh" "テストの中のインラインの Python"

d=$(copy test-inline-python-substitution)
printf 'out=$(%s -I -c %s)\n' "python3" "'print(1)'" >>"$d/tests/ctx-limit-read.sh"
expect_audit "$d" "tests/ctx-limit-read.sh" "コマンド置換の中のインラインの Python"

d=$(copy ng-stderr)
printf 'printf "%s %%s\\n" x >&2\n' NG >>"$d/dotclaude/skills/ui-record/scripts/record-video.sh"
expect_audit "$d" "失敗を stderr に出している" "printf で NG を stderr に出す .sh"

d=$(copy fail-stderr)
printf 'echo "だめ" >&2\nexit 1\n' >>"$d/dotclaude/skills/ui-record/scripts/record-video.sh"
expect_audit "$d" "失敗を stderr に出している" "NG を付けずに stderr に出して止まる .sh"

d=$(copy skill-sections)
replace "$d/dotclaude/skills/pr-prune/SKILL.md" '## 報告' '## 結果'
expect_audit "$d" "## 報告 が無い" "SKILL.md に報告の節が無い"

d=$(copy skill-order)
printf '\n## 入力\n\nx\n' >>"$d/dotclaude/skills/ctx-report/SKILL.md"
expect_audit "$d" "## 入力 は" "SKILL.md の節の順が違う"

d=$(copy skill-order-fence)
printf '\n~~~text\n```swift\n~~~\n\n## 入力\n\nx\n' >>"$d/dotclaude/skills/ctx-report/SKILL.md"
expect_audit "$d" "## 入力 は" "チルダの囲みの中のバッククォートで、囲みの外の見出しを見落とさない"

d=$(copy agent-last)
printf '\n## 補足\n\nx\n' >>"$d/dotclaude/agents/explorer.md"
expect_audit "$d" "最後の ## は「返す形」" "agents の最後の節が返す形ではない"

d=$(copy prefix-unknown)
git -C "$d" mv -q dotclaude/hooks/swift-format.py dotclaude/hooks/format-swift.py 2>/dev/null || mv "$d/dotclaude/hooks/swift-format.py" "$d/dotclaude/hooks/format-swift.py"
expect_audit "$d" "名前の接頭語が接頭語の表に無い: format-swift.py" "表に無い接頭語のフック"

d=$(copy prefix-place)
mv "$d/scripts/docs-section.sh" "$d/scripts/pr-section.sh"
expect_audit "$d" "接頭語 pr- は scripts に使わない" "使う所の違う接頭語"

d=$(copy verb-ok)
replace "$d/docs/config/development.md" '| `record`・`render`・' '| `glue`・`record`・`render`・'
mv "$d/dotclaude/skills/ui-record/scripts/tile-frames.sh" "$d/dotclaude/skills/ui-record/scripts/glue-frames.sh"
replace "$d/dotclaude/skills/ui-record/SKILL.md" 'tile-frames.sh' 'glue-frames.sh'
expect_audit "$d" OK "動詞の表にある動詞で始まるスクリプト"

d=$(copy verb-ng)
mv "$d/dotclaude/skills/ui-record/scripts/record-video.sh" "$d/dotclaude/skills/ui-record/scripts/video-record.sh"
expect_audit "$d" "頭の動詞が動詞の表に無い: video" "動詞で始まらないスクリプト"

d=$(copy path-ok)
printf '\n`hooks/<名前>.py` と `scripts/verify.sh` を読む。\n' >>"$d/docs/app/ios-architecture.md"
expect_audit "$d" OK "印の入ったパスと、アプリのひな形にあるパス"

d=$(copy path-ng)
printf '\n`hooks/nothing.py` を読む。\n' >>"$d/docs/app/ios-architecture.md"
expect_audit "$d" "参照先が無い: hooks/nothing.py" "無いファイルへのパス"

d=$(copy path-tests-ng)
printf '\n`tests/nothing.sh` を読む。\n' >>"$d/docs/app/ios-architecture.md"
expect_audit "$d" "参照先が無い: tests/nothing.sh" "tests/ に無いファイルへのパス"

d=$(copy ledger-no-path)
add_ledger_row "$d/docs/config/improvements.md" '| 🟡 低 | 前置きだけの文 | 中身 |'
expect_audit "$d" "台帳の場所の先頭にパスが無い: 前置きだけの文" "台帳の場所にパスが無い行"

d=$(copy ledger-path-later)
add_ledger_row "$d/docs/config/improvements.md" '| 🟡 低 | 前置きの文 `dotclaude/skills/pr-create/scripts/hash-state.sh` | 中身 |'
expect_audit "$d" "台帳の場所の先頭にパスが無い: 前置きの文" "台帳の場所のパスが先頭に無い行"

d=$(copy ledger-docs-missing-path)
add_ledger_row "$d/docs/config/improvements.md" '| 🟡 低 | `README.nothing` | 中身 |'
expect_audit "$d" "台帳の場所のパスが無い: README.nothing" "文書の台帳の場所のパスが無い行"

d=$(copy ledger-missing-path)
add_ledger_row "$d/docs/config/improvements.md" '| 🟡 低 | `hooks/nothing.sh` | 中身 |'
expect_audit "$d" "台帳の場所のパスが無い: hooks/nothing.sh" "台帳の場所のパスが無い行"

d=$(copy ledger-missing)
rm "$d/docs/config/improvements.md"
expect_audit "$d" "台帳が無い" "台帳のファイルが無い時に NG を出す"

d=$(copy template-script-ng)
replace "$d/dotclaude/skills/app-init/templates/ios-app/Makefile" 'scripts/render-snapshots.sh' 'scripts/render.sh'
expect_audit "$d" "claude-config の参照先が無い: dotclaude/skills/ui-snapshot/scripts/render.sh" "ひな形の Makefile が無いスクリプトを呼ぶ"

d=$(copy template-token-ng)
printf '\n__Nothing__\n' >>"$d/dotclaude/skills/app-init/templates/ios-app/docs/roadmap.md"
expect_audit "$d" "tokens に無い印: __Nothing__" "ひな形に置き換えない印がある"

d=$(copy template-token-deep-ng)
printf '\n# __Bundle__\n' >>"$d/dotclaude/skills/app-init/templates/ios-app/Makefile"
expect_audit "$d" "tokens に無い印: __Bundle__" "ios-app の深い階層の印も見る"

d=$(copy template-token-name-ng)
replace "$d/dotclaude/skills/app-init/scripts/replace-placeholders.py" '("__Summary__",' '("<Summary>",'
expect_audit "$d" "tokens に __<名前>__ でない文字列がある: <Summary>" "tokens に印の形でない文字列がある"

d=$(copy template-token-direct-ng)
printf '\n\ndef extra(text):\n    return text.replace("<x>", "y")\n' >>"$d/dotclaude/skills/app-init/scripts/replace-placeholders.py"
expect_audit "$d" "tokens を通さずに文字列を置き換えている: <x>" "tokens を通さずに置き換える"

d=$(copy skill-dir-ok)
printf '\n`${CLAUDE_SKILL_DIR}/templates/<セット>/` を写す。\n' >>"$d/dotclaude/skills/ui-snapshot/SKILL.md"
expect_audit "$d" OK "印の入った CLAUDE_SKILL_DIR の参照"

d=$(copy skill-dir-ng)
printf '\n`${CLAUDE_SKILL_DIR}/templates/nothing/` を写す。\n' >>"$d/dotclaude/skills/ui-snapshot/SKILL.md"
expect_audit "$d" "参照先が無い: templates/nothing" "無いひな形への CLAUDE_SKILL_DIR の参照"

d=$(copy agent-tools-ok)
replace "$d/dotclaude/agents/implementer.md" 'model: sonnet
' 'model: sonnet
tools: Read, Edit
'
expect_audit "$d" OK "書き換えるエージェントは Edit を持てる"

d=$(copy agent-tools-ng)
replace "$d/dotclaude/agents/explorer.md" 'tools: Read, Grep, Glob, Bash
' ''
expect_audit "$d" "書き換えないエージェントは tools を書き" "書き換えないエージェントが全部の道具を持つ"

d=$(copy agent-tools-write)
replace "$d/dotclaude/agents/explorer.md" 'tools: Read, Grep, Glob, Bash' 'tools: Read, Grep, Glob, Bash, Write'
expect_audit "$d" "書き換えないエージェントは tools を書き" "書き換えないエージェントが Write を持つ"

d=$(copy agent-tools-notebook-edit)
replace "$d/dotclaude/agents/reviewer.md" 'tools: Read, Grep, Glob, Bash' 'tools: Read, Grep, Glob, Bash, NotebookEdit'
expect_audit "$d" "書き換えないエージェントは tools を書き" "書き換えないエージェントが NotebookEdit を持つ"

d=$(copy claude-template-ok)
replace "$d/dotclaude/skills/app-init/templates/ios-app/CLAUDE.md" '## 構成
' '## コードの書き方
'
expect_audit "$d" OK "ひな形の CLAUDE.md の節が決まった順"

d=$(copy claude-template-ng)
replace "$d/dotclaude/skills/app-init/templates/ios-app/CLAUDE.md" '## 作業の進め方' '## 進め方'
expect_audit "$d" "CLAUDE.md の ## は" "ひな形の CLAUDE.md の節の順が違う"

d=$(copy template-link-ok)
printf '\n[r](docs/roadmap.md)\n' >>"$d/dotclaude/skills/app-init/templates/ios-app/README.md"
expect_audit "$d" OK "ひな形の中で、写した後に辿れるリンク"

d=$(copy template-link-ng)
printf '\n[x](docs/nothing.md)\n' >>"$d/dotclaude/skills/app-init/templates/ios-app/README.md"
expect_audit "$d" "リンク先が無い: docs/nothing.md" "ひな形の中の壊れたリンク"

d=$(copy lib-name)
printf 'value = 1\n' >"$d/lib/hookIO.py"
expect_audit "$d" "lib/hookIO.py:1 lib の名前は" "snake_case でない lib"

d=$(copy lib-unlisted)
printf 'value = 1\n' >"$d/lib/hook_extra.py"
expect_audit "$d" "lib/hook_extra.py:1 lib/README.md の表に載っていない" "lib/README.md に無い lib"

d=$(copy test-lib-name)
printf 'helper() { :; }\n' >"$d/tests/support/test-helpers.sh"
expect_audit "$d" "tests/support/test-helpers.sh:1 tests/support の名前は" "snake_case でない tests/support"

d=$(copy agent-name)
cp "$d/dotclaude/agents/explorer.md" "$d/dotclaude/agents/search.md"
expect_audit "$d" "dotclaude/agents/search.md:1 エージェントの名前は" "-er で終わらないエージェント"

d=$(copy hook-extra)
printf 'x\n' >"$d/dotclaude/hooks/notes.txt"
expect_audit "$d" "dotclaude/hooks/notes.txt:1 hooks/ に置く .py 以外のファイルは run.sh だけ" "hooks/ の run.sh 以外の .py でないファイル"

finish
