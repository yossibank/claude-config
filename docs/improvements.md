# 改善の台帳

> [!NOTE]
> claude-config の調べ直しで見つけて、まだ直していない改善と、直さないと決めたことが分かる。
> 調べ方は [config-review](../skills/config-review/SKILL.md) にある。

## 📏 台帳の書き方

台帳は、残っている改善と見送ったことだけを持つ。直した改善は行を消し、経緯は git の履歴に任せる。

| 場面 | すること |
| --- | --- |
| 調べ直した | 人が選ばなかった指摘を「残っている改善」に足す。「場所」列の先頭に、リポジトリのパスをバッククォートで書く |
| PR で直した | 同じ PR で、その行を消す |
| 直さないと決めた | 「直さないと決めたこと」に、理由と一緒に移す |
| 前提が変わった | 見送りの理由が無くなったら、行を消す |
| パスが無い | 「場所」列の先頭にパスが無い行や、実在しないパスの行は、config-audit が NG にする |

## 📝 残っている改善

分類ごとに、重さの高い順に並べる。直す時は、同じ分類の行をまとめて 1 本の PR にする。

### バグ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `skills/docs-polish/scripts/check-layout.py` | `docs/` を渡すと、その下の `docs/**` を探して「文書が無い」で NG になる |
| 🟡 低 | `hooks/run.sh` | `CC_HOOKS_OFF` の知らない名前を、見えない stderr に出す。フックの JSON と 1 つにまとめる仕組みが要る |
| 🟡 低 | `skills/ui-record/scripts/tile-frames.sh` | crop にカンマがあると filter が壊れる |
| 🟡 低 | `lib/git.sh` | `changed_paths` の終了コードが、diff の失敗を隠す |
| 🟡 低 | `lib/git.sh` | ls-remote が落ちると、黙って origin/main にする |
| 🟡 低 | `skills/pr-create/scripts/route-pr.sh` | detached HEAD でブランチが空のまま URL を作る |
| 🟡 低 | `skills/app-init/scripts/replace-placeholders.py` | `os.rename` が既存のファイルを上書きする |
| 🟡 低 | `skills/ui-snapshot/scripts/render-snapshots.sh` | 終了コードに xcodebuild の値（65 など）をそのまま使う |
| 🟡 低 | `skills/store-release/scripts/take-screenshot.sh` | `status_bar` の上書きを、撮った後に戻さない |
| 🟡 低 | `skills/store-release/scripts/check-listing.py` | keywords の改行を見ない |
| 🟡 低 | `skills/store-release/scripts/check-privacy.py` | dict でない要素で AttributeError になる |
| 🟡 低 | `skills/ui-snapshot/scripts/add-target.py` | Swift に入れる文字列をエスケープしない |
| 🟡 低 | `skills/docs-polish/scripts/check-layout.py` | `> ` だけの 1 行で「表示あり」になる |
| 🟡 低 | `skills/config-learn/scripts/collect-corrections.py` | `-C` の値に空白があると切れる |
| 🟡 低 | `hooks/swift-format.py` | mint が無いと黙って通す |
| 🟡 低 | `scripts/config-install.sh` | diff の終了コード 2 を「違う」と同じに扱う |
| 🟡 低 | `skills/pr-fix/scripts/list-threads.sh` | reviews と comments の `last:100` にページ送りが無い |

### 文書の読みやすさ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `README.md` の「フック」 | 冒頭の文が「止める」だけで、表の知らせるフックと整えるフックに合わない |
| 🟠 中 | `README.md` の「入れ方」 | 前提の NOTE が手順の間にある。前提を先に置き、手順を番号付きにする |
| 🟠 中 | `docs/architecture-ios.md` | 「make のコマンド」がフォルダの木の間にある。「動かし方」の節に出す |
| 🟠 中 | `skills/code-debug/SKILL.md` | 手順に「効かなかった変更を戻す」「直ったら 1 つずつ外す」が無い |
| 🟠 中 | `skills/store-release/SKILL.md` | PrivacyInfo のひな形のパスが途中まで。実際は `ios-app/ios/__App__/` の下にある |
| 🟠 中 | `docs/architecture-ios.md` | 「UI テストは書かない」が ui-snapshot と食い違う |
| 🟡 低 | `docs/architecture-ios.md` の「パッケージ」 | Kit と App の違いが 3 か所に散らばる。節の頭に比べる表を置く |
| 🟡 低 | `docs/architecture-ios.md` | `0xdead10cc` の理由をアラートにし、依存の向きを太字にする |
| 🟡 低 | `README.md` の「入れ方」の手順 | 「実体」「2 つ」の指す先が読めない。settings.json が 1 文に 3 回出る |
| 🟡 低 | `README.md` のフックの表 | 列の名前の「動く時」と「当たる時」の違いが分からない |
| 🟡 低 | `docs/development.md` の表 | フックとひな形の印の行で、1 つのセルに別々の指示がある |
| 🟡 低 | `docs/development.md` | 前置きだけの文が、スクリプトの表と testing.md のテストの表の前などにある。見出しで分かるので消す |
| 🟡 低 | `agents/debugger.md` | 「未確認」と「未確定」が混ざる |
| 🟡 低 | `skills/store-report/SKILL.md` | 「上下は無い」と「Admin にする」が食い違う |
| 🟡 低 | `skills/store-release/SKILL.md` | 字数の表に、更新の説明（4000 字）が無い |
| 🟡 低 | `skills/app-init/SKILL.md` | 置き換えの印に `__Summary__` が無い。docs/architecture-ios.md が相対パスで書かれている |
| 🟡 低 | `skills/pr-create/SKILL.md` | docs-check.py の呼び方が無い |
| 🟡 低 | `skills/ui-record/SKILL.md` | 入力の節が無い |
| 🟡 低 | `agents/explorer.md` | debugger・explorer・reviewer の description に「使わない時」が無い |
| 🟡 低 | `agents/tester.md` | 「直さない」と「わざと壊して戻す」が食い違って読める |
| 🟡 低 | `rules/swift-core.md` | 空行の決まりの範囲が読み取りにくい |
| 🟡 低 | `rules/swift-ui.md` | 指す先の名前が無い |
| 🟡 低 | `output-styles/report.md` | 見出しの絵文字の扱いが、`rules/docs-claude.md` と食い違う |
| 🟡 低 | `skills/config-learn/SKILL.md` | 0 回の行の扱いが無い |
| 🟡 低 | `skills/store-reply/SKILL.md` | description の `py*` と `py *` が揺れる |
| 🟡 低 | `README.md` | WARNING を IMPORTANT にする。「上の PR」と見出し「一覧」が読みにくい |
| 🟡 低 | `docs/architecture-ios.md` | spec/ の扱い、「裏に回る前の対策」「開く」の言い方が揺れる |
| 🟡 低 | `README.md` | 「CI は置かない」と「make verify を通す」が重なる |
| 🟡 低 | `skills/app-init/templates/ios-app/docs/overview.md` | 「上の表」、CLAUDE.md の「共通の形」、README の main 固定 URL が指す先を読めない |

### 名前と並び

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `settings/settings.json` | 表と一覧の並べる順の決まりが無い。許可とフックも名前の順でない |
| 🟠 中 | `settings/settings.json` | Makefile に無い `make build` を許可している |
| 🟡 低 | `skills/pr-fix/scripts/list-threads.sh` | GitHub から取ってくるので、動詞は `fetch` にする |
| 🟡 低 | `tests/lib/hooks.sh` | `hooks/` と名前が重なる。`hook_fixtures.sh` にする |
| 🟡 低 | `skills/ui-snapshot/templates/screen/` | SKILL.md の呼び名の「セット」に合わせて `set/` にする |
| 🟡 低 | `scripts/` の拡張子違いの組 | `.sh` が入口でほかが中身、という決まりを書き、検査にする |
| 🟡 低 | `docs/development.md` の動詞の表 | 1 行に動詞を詰めている。`search` は外の API も呼ぶので定義と合わない |
| 🟡 低 | `docs/development.md` のスクリプトの表 | `scripts/config-install.jq` の行が無い |
| 🟡 低 | `README.md` の「確かめ方」 | スクリプトの一覧が、`docs/development.md` の表と重なる |
| 🟡 低 | `settings/settings.json` | `make test` の許可が重なる |
| 🟡 低 | `hooks/rules-detect-bash-edits.py` | pre と post が同じ引数 `edit` で呼ばれる |
| 🟡 低 | `docs/development.md` | 接頭語 `rules-` の説明が、役目と合わない |
| 🟡 低 | `skills/app-init/templates/ios-app/ios/Packages/__App__App/Package.swift` | `AppFeature/` と `Features/`、`__App__App` の名前が紛らわしい |
| 🟡 低 | `scripts/config-install.jq` | `ours` と、`claude-config-allow.json` の名前が役目を表さない |
| 🟡 低 | `docs/improvements.md` | 「改善の台帳」と「台帳」の呼び方が揺れる |

### 処理と速さ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `scripts/config-audit.py`・`hooks/docs-check.py` | 500 行を超える。検査の種類ごとに lib へ分ける |
| 🟠 中 | `hooks/rules-detect-bash-edits.py` | ls や cat などの読むだけのコマンドでも、`git status` を 2 回走らせる |
| 🟠 中 | `hooks/rules-require-read.py` | 編集のたびに会話の記録を最大 32MB 読み直す。読んだ所を覚えて続きだけ読む |
| 🟡 低 | `skills/pr-prune/scripts/prune-merged.sh` | 載せ直しの処理を別のスクリプトに分け、グローバル変数をやめる |
| 🟡 低 | `lib/md_blocks.py` | 見出しの読み方が 4 か所で別々にある。ここに 1 つにまとめる |
| 🟡 低 | `lib/hook_state.py` | 呼ぶたびに状態のフォルダを全部見て掃除する。1 時間に 1 回にする |
| 🟡 低 | `lib/app_store.py` | ページをめくるたびに openssl で署名する。期限までトークンを使い回す |
| 🟡 低 | `lib/script_io.py` | OK と NG の集計が 3 か所、アプリ ID の確かめが 2 か所にある |
| 🟡 低 | `docs/development.md` の「結果」 | データを返すスクリプトは OK と NG を出さない。その形を決まりに書く |
| 🟡 低 | `tests/config-audit.sh` | 手助けの関数を `tests/lib/` に移し、`python3 -c` と `assert` をやめる |
| 🟡 低 | `skills/ui-snapshot/scripts/render-snapshots.sh` | 終了コードを `set +e` で受けている。決まりの `status=$?` の形にする |
| 🟡 低 | `skills/pr-create/scripts/hash-state.sh` | `git add -A` を確認のたびに 2 回走らせる |
| 🟡 低 | `hooks/docs-check.py` | 使わない `language` の代入がある |
| 🟡 低 | `lib/md_doc.py` | リンクを除く処理が `hooks/docs-check.py` と 2 か所にある |

### テスト

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `lib/app_store.py` | 署名の DER を読む処理にテストが無い |
| 🟠 中 | `tests/pr-fix.sh` | 偽の gh が完成した行を返し、未解決に絞る式が走らない |
| 🟠 中 | `tests/pr-prune.sh` | squash でないマージのテストに子のブランチが無く、空振りする |
| 🟡 低 | `tests/pr-prune.sh` | ls-remote が落ちた時に付け替えを見送る道に、テストが無い |
| 🟡 低 | `tests/lib/assert.sh` | 利用者の `~/.gitconfig` が効く。`GIT_CONFIG_GLOBAL` を `/dev/null` にする |
| 🟡 低 | `lib/git.py`・`lib/git.sh` | ワークツリーの置き場所を 2 か所で決めている。同じかを確かめるテストが無い |
| 🟡 低 | `tests/rules-require-read.sh` | `tests/lib/hooks.sh` が HOME を分けない。`sleep 1` と date に頼る |
| 🟡 低 | `tests/pr-prune.sh` | 準備の失敗を `2>/dev/null` で消す |
| 🟡 低 | `tests/store-release.sh` | 字数の上限ちょうどが通るテストが無い。fixtures.sh を 2 度 source する |
| 🟡 低 | `tests/store-reply.sh` | 字数の上限ちょうどが通るテストが無い |
| 🟡 低 | `tests/ui-snapshot.sh` | iPhone 1 台で「先頭」を確かめていない |
| 🟡 低 | `tests/rules-detect-bash-edits.sh` | cd 先に `app/` が無い場合のテストが無い |
| 🟡 低 | `tests/lib/hooks.sh` | JSON を文字列で組んでいる |
| 🟡 低 | `tests/shell-check.sh` | 対象外の入力のテストが無い。`tests/swift-format.sh`・`tests/ctx-limit-read.sh` も同じ |

### 検査にする案

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `scripts/config-audit.py` | 例外の時に NG の行が出ない main を見つける |
| 🟠 中 | `scripts/config-audit.py` | SKILL.md の手順のコマンドと allowed-tools を照らし合わせる |
| 🟠 中 | `scripts/config-audit.py` | `tests/app-init.sh` などの `python3 -c` を対象にする |

## ⚠️ 直さないと決めたこと

調べ直しで出ても、次のものは指摘にしない。

| 中身 | 理由 |
| --- | --- |
| statusLine を足す | 人が要らないと決めた |
| `run-check.sh` の古いロックの競合を直す | mkdir と rmdir だけでは、競合を残さずに直せない |
| `make test` を並べて走らせる | 人が見送ると決めた |
| bash 5.2 で確かめる | 手元の bash が 3.2 だけで、確かめる場所が無い |
| `docs-section.sh`・`rules-detect-bash-edits.py` の改名 | 人が打つ名前なので、慣れた名前を残す |
| `run-check.sh`・`hooks/run.sh` の改名 | 参照が 30 件近くあり、変える益が小さい |
| `find-simulator.sh` の写しを 1 つにする | ひな形のアプリが単独で動くように、写しを持つ。同じかはテストで見る |
| lib の `.sh` と `.py` をフォルダで分ける | `source` のパスが 12 か所で変わり、益が小さい |
| 前置きの文を機械で止める | 要る前置きと要らない前置きを、文字だけでは分けられない |
| 「時」を使わず、ひらがなの書き方にそろえる | 「時」を止めると、「時間」「時刻」まで当たる |
