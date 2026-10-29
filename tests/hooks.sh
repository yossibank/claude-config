#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

export TMPDIR="$work/state/"
mkdir -p "$TMPDIR"
hooks="$root/hooks/run.sh"
check="$root/skills/pr-create/scripts/run-check.sh"
rules="$root/rules"

app="$work/app"
mkdir -p "$app/ios/Features" "$app/docs"
echo 'struct A {}' >"$app/ios/Features/HomeView.swift"
echo '# 概要' >"$app/docs/overview.md"
echo '{}' >"$app/data.json"
git -C "$app" init -q
commit "$app" init
swift="$app/ios/Features/HomeView.swift"

run() {
    local hook=$1 expect=$2 label=$3 payload=$4 out status
    shift 4
    out=$(echo "$payload" | bash "$hooks" "$hook" "$@" 2>&1)
    status=$?
    if [[ $status == "$expect" ]]; then
        ok "$label"
    else
        ng "${label}（終了コード ${status}、期待は ${expect}）" "$out"
    fi
}

edit() {
    echo "{\"session_id\":\"$1\",\"agent_id\":\"$2\",\"tool_name\":\"Edit\",\"transcript_path\":\"$3\",\"tool_input\":{\"file_path\":\"$4\"}}"
}

read_rule() {
    echo "{\"session_id\":\"$1\",\"agent_id\":\"$2\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$rules/$3\"}}" | bash "$hooks" rules-require-read
}

bash_call() {
    echo "{\"session_id\":\"b\",\"tool_use_id\":\"$1\",\"cwd\":\"$app\",\"tool_input\":{\"command\":\"$2\"}}"
}

log="$work/t.jsonl"
: >"$log"
run rules-require-read 2 "rules: 読まずに Swift を編集すると止まる" "$(edit s1 main "$log" "$swift")"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s1 main "$name"; done
run rules-require-read 0 "rules: Read した後は通る" "$(edit s1 main "$log" "$swift")"
sleep 1
echo "{\"type\":\"system\",\"subtype\":\"compact_boundary\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}" >>"$log"
sleep 1
run rules-require-read 2 "rules: 読んだ後に圧縮があれば、また止まる" "$(edit s1 main "$log" "$swift")"
auto="$HOME/.claude/rules"
echo "{\"type\":\"attachment\",\"attachment\":{\"type\":\"instructions\",\"files\":[{\"path\":\"$auto/code-comments.md\"},{\"path\":\"$auto/swift-core.md\"},{\"path\":\"$auto/swift-ui.md\"}]}}" >>"$log"
run rules-require-read 0 "rules: 圧縮の後に自動で読み込まれた印があれば通る" "$(edit s1 main "$log" "$swift")"
run rules-require-read 0 "rules: 当たる rules が無いファイルは止めない" "$(edit s1 main "$log" "$app/data.json")"
echo '# メモ' >"$work/memo.md"
run rules-require-read 0 "rules: git の外のファイル（メモリ・プラン）は止めない" "$(edit s1 main "$log" "$work/memo.md")"
: >"$work/empty.jsonl"
for name in code-comments.md swift-core.md swift-ui.md; do read_rule s3 main "$name" & done
wait
run rules-require-read 0 "rules: 同時に Read しても取りこぼさない" "$(edit s3 main "$work/empty.jsonl" "$swift")"
fresh="$work/t2.jsonl"
: >"$fresh"
for name in docs-writing.md docs-app.md; do read_rule s2 main "$name"; done
run rules-require-read 2 "rules: サブエージェントは親の記録を使わない" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
for name in docs-writing.md docs-app.md; do read_rule s2 a1 "$name"; done
run rules-require-read 0 "rules: サブエージェントが自分で読めば通る" "$(edit s2 a1 "$fresh" "$app/docs/overview.md")"
CLAUDE_HOOKS_OFF="pr-gate rules-require-read" run rules-require-read 0 "rules: CLAUDE_HOOKS_OFF に名前があれば止めない" "$(edit s9 main "$fresh" "$swift")"
run rules-require-read 0 "rules: 壊れた入力では止めない" "not json"

printf '#!/bin/bash\necho "x $name%s"\n' '。' >"$work/wide.sh"
printf '#!/bin/bash\necho "x ${name}。"\n' >"$work/ok.sh"
run shell-check 2 "shell: 変数の直後の全角で止まる" "{\"tool_input\":{\"file_path\":\"$work/wide.sh\"}}"
run shell-check 0 "shell: \${名前} で囲めば通る" "{\"tool_input\":{\"file_path\":\"$work/ok.sh\"}}"

python3 -I -c 'print("a" * 40000)' >"$work/big.md"
run ctx-limit-read 2 "ctx: 大きいファイルを範囲なしで読むと止める" "{\"tool_input\":{\"file_path\":\"$work/big.md\"}}"
run ctx-limit-read 0 "ctx: limit を付ければ通す" "{\"tool_input\":{\"file_path\":\"$work/big.md\",\"limit\":10}}"
run ctx-limit-read 0 "ctx: 壊れた入力では止めない" "not json"

usage='{"type":"assistant","message":{"usage":{"input_tokens":1,"cache_read_input_tokens":250000}}}'
echo "$usage" >"$work/long.jsonl"
out=$(echo "{\"session_id\":\"c1\",\"transcript_path\":\"$work/long.jsonl\"}" | bash "$hooks" ctx-suggest-clear)
check "ctx: 20 万トークンを超えたら区切りを勧める" grep -q systemMessage <<<"$out"
out=$(echo "{\"session_id\":\"c1\",\"transcript_path\":\"$work/long.jsonl\"}" | bash "$hooks" ctx-suggest-clear)
check "ctx: 同じ段では 2 回勧めない" test -z "$out"
run ctx-suggest-clear 0 "ctx: 壊れた入力でも落ちない" "not json" pr

run swift-format 0 "swift: .swiftformat が無ければ何もしない" "{\"tool_input\":{\"file_path\":\"$swift\"}}"

doc_case() {
    local expect=$1 label=$2 name=$3 text=$4 want=${5:-} out status
    mkdir -p "$work/docs-case/$(dirname "$name")"
    printf '%s\n' "$text" >"$work/docs-case/$name"
    out=$(echo "{\"tool_input\":{\"file_path\":\"$work/docs-case/$name\"}}" | bash "$hooks" docs-check 2>&1)
    status=$?
    if [[ $status == "$expect" && $out == *"$want"* ]]; then
        ok "docs: $label"
    else
        ng "docs: ${label}（終了コード ${status}、期待は ${expect} と「${want}」）" "$out"
    fi
}
doc_case 0 "短い文は通る" README.md $'# t\n\n短い文である。'
doc_case 2 "コードも一文の字数に数える" README.md $'# t\n\n`/very/long/path/that/goes/on/and/on/and/on/and/on/x.sh` を走らせて結果を確かめる。'
doc_case 2 "段落は 3 文まで" README.md $'# t\n\n一つ目。二つ目。三つ目。四つ目。'
doc_case 2 "表のセルは 2 文まで" README.md $'# t\n\n表は次のとおり。\n\n| a | b |\n| --- | --- |\n| x | 一つ。二つ。三つ。 |'
doc_case 2 "Claude が読む文書に絵文字を使わない" rules/x.md $'# t\n\n✅ 済んだ。'
doc_case 0 "人が読む文書は表の絵文字を使える" README.md $'# t\n\n✅ 済んだ。'
doc_case 2 "人が読む文書でも表に無い絵文字は使わない" README.md $'# t\n\n🎉 済んだ。'
doc_case 2 "README の ## には絵文字を付ける" README.md $'# t\n\n## 🚀 入れ方\n\nあ。\n\n## 決まり\n\nい。'
doc_case 2 "## の見出しの絵文字をそろえる" docs/x.md $'# t\n\n## 🚀 入れ方\n\nあ。\n\n## 決まり\n\nい。'

note=$'# t\n\n> [!NOTE]\n> 分かる。\n'
state_badge='![CI](https://img.shields.io/github/actions/workflow/status/o/r/verify.yml?label=Verify&logo=github)'
tech_badge='![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)'
doc_case 0 "README の節は全体像・動かし方・文書の順" README.md $'# t\n\nあ。\n\n## 🗺️ 全体像\n\nい。\n\n## 🚀 入れ方\n\nう。\n\n## 📚 文書\n\nえ。'
doc_case 2 "README の文書の節を動かし方より前に置かない" README.md $'# t\n\nあ。\n\n## 📚 文書\n\nい。\n\n## 🚀 入れ方\n\nう。' "README の ## は"
doc_case 0 "docs の冒頭に [!NOTE] を置けば通る" docs/x.md "$note"
doc_case 2 "docs の冒頭に [!NOTE] が無い" docs/x.md $'# t\n\n本文である。' "タイトルの直後に [!NOTE]"
doc_case 0 "親が違えば同じ名前の見出しを使える" README.md $'# t\n\nあ。\n\n## 🚀 入れ方\n\nい。\n\n### 手順\n\nう。\n\n## 🧪 確かめ方\n\nえ。\n\n### 手順\n\nお。'
doc_case 2 "同じ親の下に同じ名前の見出しを置かない" README.md $'# t\n\nあ。\n\n## 🚀 入れ方\n\nい。\n\n### 手順\n\nう。\n\n### 手順\n\nえ。' "同じ名前の見出し"
doc_case 0 "見出しの絵文字が表にあれば通る" docs/x.md "$note"$'\n## 🪟 ウィジェット\n\nあ。'
doc_case 2 "見出しの絵文字が表に無い" docs/x.md "$note"$'\n## 🎉 祝い\n\nあ。' "表から選ぶ"
doc_case 0 "太字は 1 節に 1 か所" docs/x.md "$note"$'\n## 🚀 入れ方\n\n**一つ**だけ。\n\n## 🧪 確かめ方\n\n**一つ**だけ。'
doc_case 2 "太字を 1 節に 2 か所使わない" docs/x.md "$note"$'\n## 🚀 入れ方\n\n**一つ**と**二つ**。' "太字は 1 節に 1 か所"
doc_case 0 "冒頭の [!NOTE] とほかのアラート 1 つは通る" docs/x.md "$note"$'\n> [!WARNING]\n> 危ない。'
doc_case 2 "アラートを 1 節に 2 つ使わない" docs/x.md "$note"$'\n## 🚀 入れ方\n\n> [!TIP]\n> こつ。\n\n> [!WARNING]\n> 危ない。' "1 節に 1 つまで"
doc_case 0 "GitHub のアラートは通る" docs/x.md "$note"$'\n## 🚀 入れ方\n\n> [!CAUTION]\n> 戻せない。'
doc_case 2 "GitHub に無いアラートを使わない" docs/x.md "$note"$'\n## 🚀 入れ方\n\n> [!DANGER]\n> 危ない。' "だけを使う（DANGER）"
doc_case 0 "言語の付いたコードブロックは通る" README.md $'# t\n\nあ。\n\n```sh\nls\n```'
doc_case 2 "コードブロックに言語を付ける" README.md $'# t\n\nあ。\n\n```\nls\n```' "言語を付ける"
long='これは一文が長すぎる文になっていて、六十字を超えているはずなので、本来なら止まるべきである文であるかを確かめる長い文である。'
doc_case 2 "チルダの囲みの中のバッククォートで囲みを数え違えない" docs/x.md "$note"$'\n~~~text\n```swift\n~~~\n\n'"$long" "一文が 60 字を超えている"
doc_case 0 "4 つのバッククォートの囲みの中の 3 つは囲みを閉じない" docs/x.md "$note"$'\n````markdown\n```swift\n'"$long"$'\n```\n````'
doc_case 0 "名前だけのフォルダの木は通る" README.md $'# t\n\nあ。\n\n```text\na/\n├── b/\n└── c.md\n```'
doc_case 2 "フォルダの木に説明を書かない" README.md $'# t\n\nあ。\n\n```text\na/\n├── b/  # 部品\n└── c.md\n```' "名前だけを書く"
doc_case 0 "本文の中のページ内リンクは目次にしない" README.md $'# t\n\nあ。\n\n- [入れ方](#入れ方)'
doc_case 2 "手で目次を書かない" README.md $'# t\n\nあ。\n\n- [入れ方](#入れ方)\n- [決まり](#決まり)' "目次は GitHub が作る"
doc_case 0 "バッジは状態の段の後に技術の段" README.md $'# t\n\nあ。\n\n'"$state_badge"$'\n\n'"$tech_badge"
doc_case 2 "技術のバッジを状態のバッジより前に置かない" README.md $'# t\n\nあ。\n\n'"$tech_badge"$'\n\n'"$state_badge" "状態の段を技術の段より先"
doc_case 0 "Claude が読む文書の短いコードは通る" rules/x.md $'# t\n\nあ。\n\n- `git log` で見る。'
doc_case 2 "Claude が読む文書の文の中に長いコマンドを書かない" rules/x.md $'# t\n\nあ。\n\n- `git log --oneline --graph a..b -- x y z w` を走らせる。' "長いコマンドを書かない"
doc_case 2 "Claude が読む文書のタイトルの直後に 1 文を書く" rules/x.md $'# t\n\n- 項目である。' "タイトルの直後に、何があるかを 1 文"

run rules-detect-bash-edits 0 "bash: 書き換える前の状態を残す" "$(bash_call t1 'sed -i')" pre
sed -i '' 's/概要/概要です/' "$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: Bash で .md を書き換えると知らせて検査する" "$(bash_call t1 'sed -i')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t2 'git checkout')" pre
git -C "$app" checkout -q -- docs/overview.md
run rules-detect-bash-edits 0 "bash: git での変更は知らせない" "$(bash_call t2 'git checkout')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t3 'ls')" pre
run rules-detect-bash-edits 0 "bash: 何も変えなければ知らせない" "$(bash_call t3 'ls')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t4 'cd app && git checkout')" pre
echo 'x' >>"$app/docs/overview.md"
run rules-detect-bash-edits 0 "bash: cd と git だけのコマンドは知らせない" "$(bash_call t4 'cd app && git checkout')" post
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t5 'sed -i x && git add')" pre
echo 'y' >>"$app/docs/overview.md"
run rules-detect-bash-edits 2 "bash: git が混ざっても書き換えは知らせる" "$(bash_call t5 'sed -i x && git add')" post
echo '# 日本語' >"$app/docs/日本語.md"
run rules-detect-bash-edits 0 "bash: 前の状態を残す" "$(bash_call t6 'sed -i')" pre
echo 'z' >>"$app/docs/日本語.md"
run rules-detect-bash-edits 2 "bash: 日本語の名前のファイルの書き換えも知らせる" "$(bash_call t6 'sed -i')" post
rm -f "$app/docs/日本語.md"

push() {
    echo "{\"cwd\":\"$1\",\"tool_input\":{\"command\":\"$2\"}}"
}

run pr-gate 2 "pr: 確認の記録が無いと push を止める" "$(push "$app" 'git push -u origin feat/x')"
"$check" "$app" "true" true >/dev/null
run pr-gate 0 "pr: 確認を通せば push を通す" "$(push "$app" 'git push -u origin feat/x')"
run pr-gate 0 "pr: 確認を通せば gh pr create を通す" "$(push "$app" 'gh pr create --title x')"
echo 'struct B {}' >>"$swift"
run pr-gate 2 "pr: 確認の後に変えると止める" "$(push "$app" 'git push')"
"$check" "$app" "true" true >/dev/null
"$check" "$app" "false" false >/dev/null
run pr-gate 2 "pr: NG の確認が残ると止める" "$(push "$app" 'git push')"
"$check" "$app" --drop "false" >/dev/null
run pr-gate 0 "pr: --drop で外せば通す" "$(push "$app" 'git push')"
echo 'struct C {}' >>"$swift"
run pr-gate 0 "pr: タグの push は止めない" "$(push "$app" 'git push --tags')"
run pr-gate 0 "pr: ブランチの削除は止めない" "$(push "$app" 'git push origin --delete feat/x')"
run pr-gate 0 "pr: : で始まる refspec の削除は止めない" "$(push "$app" 'git push origin :feat/x')"
run pr-gate 2 "pr: draft の PR（gh pr create -d）も止める" "$(push "$app" 'gh pr create -d --title x')"
run pr-gate 2 "pr: 別のコマンドの -d に引きずられない" "$(push "$app" 'git branch -d old && git push')"
run pr-gate 2 "pr: git -C で別のリポジトリを指しても、そのリポジトリを見る" "$(push "$work" "git -C $app push")"
run pr-gate 0 "pr: 関係ないコマンドは止めない" "$(push "$app" 'git status')"
run pr-gate 2 "pr: cd した先のリポジトリを見る" "$(push "$work" "cd $app && git push")"
CLAUDE_HOOKS_OFF="rules-require-read pr-gate" run pr-gate 0 "pr: CLAUDE_HOOKS_OFF に名前があれば止めない" "$(push "$app" 'git push')"
CLAUDE_HOOKS_OFF="pr-gate-x" run pr-gate 2 "pr: CLAUDE_HOOKS_OFF の名前は全体で比べる" "$(push "$app" 'git push')"

finish
