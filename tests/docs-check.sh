#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

doc_case() {
    local expect=$1 label=$2 name=$3 text=$4 want=${5:-} out status
    mkdir -p "$work/docs-case/$(dirname "$name")"
    printf '%s\n' "$text" >"$work/docs-case/$name"
    out=$(echo "{\"tool_input\":{\"file_path\":\"$work/docs-case/$name\"}}" | bash "$hooks" docs-check 2>&1)
    status=$?
    if [[ $status == "$expect" && $out == *"$want"* ]]; then
        ok "docs-check: $label"
    else
        ng "docs-check: ${label}（終了コード ${status}、期待は ${expect} と「${want}」）" "$out"
    fi
}
doc_case 0 "短い文は通る" README.md $'# t\n\n短い文である。'
doc_case 2 "コードも一文の字数に数える" README.md $'# t\n\n`/very/long/path/that/goes/on/and/on/and/on/and/on/x.sh` を走らせて結果を確かめる。'
doc_case 2 "段落は 3 文まで" README.md $'# t\n\n一つ目。二つ目。三つ目。四つ目。'
doc_case 0 "一文の読点は 3 つまで通る" README.md $'# t\n\nあ、い、う、えを使う。'
doc_case 2 "一文の読点が 4 つあれば止める" README.md $'# t\n\nあ、い、う、え、おを使う。' "読点は 3 つまで"
doc_case 0 "句点の無い語の並びは、読点を数えない" README.md $'# t\n\n表は次のとおり。\n\n| a | b |\n| --- | --- |\n| x | あ、い、う、え、お |'
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
doc_case 0 "本文の中のページ内リンクは目次にしない" README.md $'# t\n\nあ。\n\n- [入れ方](#入れ方)\n- りんご\n- みかん'
doc_case 2 "手で目次を書かない" README.md $'# t\n\nあ。\n\n- [入れ方](#入れ方)\n- [決まり](#決まり)' "目次は GitHub が作る"
doc_case 0 "バッジは状態の段の後に技術の段" README.md $'# t\n\nあ。\n\n'"$state_badge"$'\n\n'"$tech_badge"
doc_case 2 "技術のバッジを状態のバッジより前に置かない" README.md $'# t\n\nあ。\n\n'"$tech_badge"$'\n\n'"$state_badge" "状態の段を技術の段より先"
doc_case 0 "Claude が読む文書の短いコードは通る" rules/x.md $'# t\n\nあ。\n\n`git log` で見る。'
doc_case 2 "Claude が読む文書の文の中に長いコマンドを書かない" rules/x.md $'# t\n\nあ。\n\n- `git log --oneline --graph a..b -- x y z w` を走らせる。' "長いコマンドを書かない"
doc_case 2 "Claude が読む文書のタイトルの直後に 1 文を書く" rules/x.md $'# t\n\n- 項目である。' "タイトルの直後に、何があるかを 1 文"
doc_case 0 "コマンドではない長いコード片は止めない" rules/x.md $'# t\n\nあ。\n\n- 向きは `App → Feature → Service → FeatureView → CoreUI` である。\n- `#expect(actual == expected, "ずれている時の説明")` で比べる。\n- 三つ目である。'
doc_case 0 "語句だけの一覧は句点を付けなくてよい" README.md $'# t\n\nあ。\n\n- りんご\n- みかん\n- ぶどう'
doc_case 0 "「」の中の句点は文の中の句点に数えない" README.md $'# t\n\nあ。\n\n- 「。」の使い方\n- りんご\n- みかん'
doc_case 2 "中に句点がある項目は末尾も句点で終える" README.md $'# t\n\nあ。\n\n- 一つ目。二つ目' "末尾も「。」"
doc_case 2 "1 つの一覧の中で文末をそろえる" README.md $'# t\n\nあ。\n\n- 文である。\n- 語句' "文末をそろえる"
doc_case 0 "入れ子の一覧は親と別に文末をそろえる" README.md $'# t\n\nあ。\n\n1. 手順である。\n   - 語句\n   - 語句\n   - 語句\n2. 次の手順である。'
doc_case 2 "パスで始まる長いコマンドは止める" rules/x.md $'# t\n\nあ。\n\n- `~/Applications/AI/claude-config/scripts/docs-section.sh <file>` を使う。' "長いコマンドを書かない"
doc_case 0 "README と docs の外は ## の絵文字を表から選ばせない" .github/pull_request_template.md $'## 👀 見どころ\n\nあ。\n\n## 🔗 関連\n\nい。'
doc_case 2 "タイトルの直後がバッジだけなら 1 文と数えない" README.md $'# t\n\n'"$state_badge"$'\n\nあ。' "タイトルの直後に、何があるかを 1 文"
doc_case 0 "空白を含むファイル名は木の説明にしない" docs/x.md "$note"$'\n```text\nApp/\n├── My File.swift\n└── b.swift\n```'
doc_case 2 "text 以外の囲みのフォルダの木も見る" docs/x.md "$note"$'\n```sh\nApp/\n├── Sources   # 説明\n```' "名前だけを書く"
doc_case 2 "状態の段に固定のバッジを置かない" docs/x.md "$note"$'\n'"$state_badge"' ![License](https://img.shields.io/badge/License-MIT-blue)' "状態の段は動的なバッジにする"
doc_case 0 "節の中のページ内リンクの一覧は目次にしない" docs/x.md "$note"$'\n## 📚 文書\n\n関係する節を次に置く。\n\n- [入れ方](#入れ方)\n- [使い方](#使い方)\n- [直し方](#直し方)'
doc_case 0 "小文字のアラートも種類を見分ける" docs/x.md $'# t\n\n> [!note]\n> 分かる。'
doc_case 2 "節の名前を並べた文は目次として止める" rules/x.md $'# t\n\n画面・文字・色・ほかの決まりがある。\n\n## 画面\n\nう。\n\n## 文字\n\nえ。\n\n## 色\n\nお。' "節の名前を並べた文は目次になる"
doc_case 0 "節の名前を 2 つ含む文は目次にしない" rules/x.md $'# t\n\n画面と文字を決める。\n\n## 画面\n\nう。\n\n## 文字\n\nえ。\n\n## 色\n\nお。'
doc_case 2 "節の名前を並べた表は目次として止める" rules/x.md $'# t\n\n決まり。\n\n| 節 | 決めること |\n| --- | --- |\n| 画面 | あ |\n| 文字 | い |\n\n## 画面\n\nう。\n\n## 文字\n\nえ。' "節の名前を並べた表は目次になる"
doc_case 0 "節の名前と一部だけ重なる表は止めない" rules/x.md $'# t\n\n決まり。\n\n| 節 | 決めること |\n| --- | --- |\n| 画面 | あ |\n| 色 | い |\n\n## 画面\n\nう。'
doc_case 0 "節の名前で属性を比べる 3 列の表は止めない" rules/x.md $'# t\n\n比べる。\n\n| 画面 | タブ | 会員 |\n| --- | --- | --- |\n| ホーム | 1 | 全員 |\n| 設定 | 4 | 全員 |\n\n## ホーム\n\nう。\n\n## 設定\n\nえ。'
doc_case 2 "## の見出しに同じ絵文字を 2 度使わない" README.md $'# t\n\n## 🚀 入れ方\n\nあ。\n\n## 🚀 使い方\n\nい。' "同じ絵文字を 2 度使わない（🚀）"
doc_case 2 "2 列の表の 1 列目に同じ値を繰り返さない" rules/x.md $'# t\n\n決まりは次のとおり。\n\n| 場面 | 決まり |\n| --- | --- |\n| 作る時 | あ |\n| 作る時 | い |' "1 列目に同じ値を繰り返さない（作る時）"
doc_case 0 "決定の文書は理由の行を重ねてよい" docs/decisions/x.md "$note"$'\n## 📏 保存\n\n**決定：保存する。**\n\n| 項目 | 内容 |\n| --- | --- |\n| 理由 | あ |\n| 理由 | い |'
doc_case 0 "条件を組み合わせる 3 列の表は 1 列目が重なってよい" rules/x.md $'# t\n\n案は次のとおり。\n\n| 決まり | 回数 | 案 |\n| --- | --- | --- |\n| 無い | 2 回 | 足す |\n| 無い | 1 回 | 待つ |'
doc_case 0 "別の表なら 1 列目が同じでもよい" rules/x.md $'# t\n\n一つ目の表。\n\n| a | b |\n| --- | --- |\n| x | 1 |\n\n二つ目の表。\n\n| a | b |\n| --- | --- |\n| x | 2 |'

doc_case 2 "箇条書きを 1 項目に使わない" rules/x.md $'# t\n\nあ。\n\n- 一つだけの項目である。' "箇条書きを 1 項目に使わない"
doc_case 2 "箇条書きを 2 項目に使わない" README.md $'# t\n\nあ。\n\n- りんご\n- みかん' "箇条書きを 2 項目に使わない"
doc_case 2 "入れ子の 2 項目の箇条書きも止める" rules/x.md $'# t\n\nあ。\n\n1. 手順である。\n   - 語句\n   - 語句\n2. 次の手順である。' "箇条書きを 2 項目に使わない"
doc_case 0 "空行を挟んだ 3 項目の箇条書きは通る" README.md $'# t\n\nあ。\n\n- りんご\n\n- みかん\n\n- ぶどう'
doc_case 0 "番号付きの手順は 2 項目でも通る" rules/x.md $'# t\n\nあ。\n\n1. 手順である。\n2. 次の手順である。'
doc_case 0 "チェックリストは 1 項目でも通る" README.md $'# t\n\nあ。\n\n- [ ] 確かめる'
doc_case 2 "冒頭の [!NOTE] を 4 行にしない" docs/x.md $'# t\n\n> [!NOTE]\n> 一つ。\n> 二つ。\n> 三つ。\n> 四つ。' "冒頭の [!NOTE] は 3 行まで"
doc_case 0 "冒頭の [!NOTE] は 3 行まで書ける" docs/x.md $'# t\n\n> [!NOTE]\n> 一つ。\n> 二つ。\n> 三つ。'
doc_case 2 "敬体の文を書かない" rules/x.md $'# t\n\n設定を読みます。' "敬体"
doc_case 2 "表のセルの敬体も止める" README.md $'# t\n\nあ。\n\n| a | b |\n| --- | --- |\n| x | 使えます |' "敬体"
doc_case 0 "コードの囲み・引用・インラインコードの敬体は止めない" rules/x.md $'# t\n\n`返します。` を出す。\n\n> 送ります。\n\n```text\nありがとうございます。\n```'
doc_case 0 "「でした」で終わる常体は止めない" rules/x.md $'# t\n\n広い探索を自分でした。'

doc_case 0 "項目の下の字下げした段落とコードの囲みで一覧を切らない" README.md $'# t\n\nあ。\n\n- 一つ目\n\n  補足。\n\n  ```sh\n  ls\n  ```\n\n- 二つ目\n- 三つ目'
doc_case 0 "冒頭の [!NOTE] のリンクだけの行は数えない" docs/x.md $'# t\n\n> [!NOTE]\n> 一つ。\n> 二つ。\n> 三つ。\n> [README](../README.md)・[開発](development.md)'
doc_case 2 "冒頭の [!NOTE] のリンクを含む文は数える" docs/x.md $'# t\n\n> [!NOTE]\n> 一つ。\n> 二つ。\n> 三つ。\n> 詳しくは [README](../README.md) にある。' "冒頭の [!NOTE] は 3 行まで"
doc_case 0 "引き継ぎのメモは見ない" .claude/handoff.md $'# t\n\n- 目的：直す'
doc_case 0 "「ます」で終わる常体の動詞は止めない" rules/x.md $'# t\n\n人を励ます。眠気を醒ます。人をだます。\n\n子をはげます。'
doc_case 2 "「上げます」は敬体として止める" rules/x.md $'# t\n\n値を上げます。' "敬体"

doc_case 2 "一覧の前置きに項目の数を書かない" README.md $'# t\n\n果物は 3 種類ある。\n\n- りんご\n- みかん\n- ぶどう' "一覧の前置きに項目の数を書かない"
doc_case 0 "数を書かない一覧の前置きは通る" README.md $'# t\n\n果物は次のとおり。\n\n- りんご\n- みかん\n- ぶどう'
doc_case 2 "使ってよい HTML ではないタグを使わない" README.md $'# t\n\nあ。\n\n<div>い。</div>' "使ってよい HTML ではない（<div>）"
doc_case 0 "README は決まった HTML のタグを使える" README.md $'# t\n\nあ。\n\n<details>\n<summary>開く</summary>\n\nい。\n\n</details>'
doc_case 2 "斜体を使わない" README.md $'# t\n\n*強調* した。' "斜体を使わない"
doc_case 0 "太字は斜体に数えない" README.md $'# t\n\n**強調** した。'
doc_case 2 "日本語と英数字の間に半角スペースを入れる" README.md $'# t\n\nGitを使う。' "半角スペースを入れる"
doc_case 0 "日本語と英数字の間に半角スペースがあれば通る" README.md $'# t\n\nGit を使う。'
big=$(printf '%016000d' 0)
doc_case 2 "docs の 1 ファイルを 15KB より大きくしない" docs/x.md "$note"$'\n```text\n'"$big"$'\n```' "15KB を超えている"
doc_case 0 "docs の外のファイルは 15KB を超えてもよい" README.md $'# t\n\nあ。\n\n```text\n'"$big"$'\n```'

finish
