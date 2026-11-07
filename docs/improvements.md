# 台帳

> [!NOTE]
> claude-config の調べ直しで見つけて、まだ直していない改善と、直さないと決めたことが分かる。文書の改善は [improvements-docs](improvements-docs.md) にある。
> 調べ方は [config-review](../skills/config-review/SKILL.md) にある。

## 📏 台帳の書き方

台帳は、残っている改善と見送ったことだけを持つ。文書と名前の改善は [improvements-docs](improvements-docs.md) に置く。直した改善は行を消し、経緯は git の履歴に任せる。

| 場面 | すること |
| --- | --- |
| 調べ直した | 人が選ばなかった指摘を「残っている改善」に足す。「場所」列の先頭に、リポジトリのパスをバッククォートで書く |
| PR で直した | 同じ PR で、その行を消す |
| 直さないと決めた | 「直さないと決めたこと」に、理由と一緒に移す |
| 前提が変わった | 見送りの理由が無くなったら、行を消す |
| パスが無い | 「場所」列の先頭にパスが無い行や、実在しないパスの行は、config-audit が NG にする |

## 📝 残っている改善

分類ごとに、重さの高い順に並べる。文書の読みやすさと名前と並びは、別の台帳に置く。直す時は、同じ分類の行をまとめて 1 本の PR にする。

### バグ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `skills/docs-polish/scripts/check-layout.py` | `docs/` を渡すと、その下の `docs/**` を探して「文書が無い」で NG になる |
| 🟠 中 | `skills/store-release/scripts/create-custom-pages.py` | 途中で止まったページを、同じ名前があるだけで OK にする |
| 🟠 中 | `skills/pr-create/scripts/write-body.sh` | 差分が無い時、重さの行を落として exit 0 で終える |
| 🟠 中 | `hooks/swift-format.py` | Swift を編集するたびに mint を最大 60 秒待つ。`pinned()` がコメントの行でも真になる |
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
| 🟡 低 | `lib/hook_state.py` | 古いフォルダを、中の新しい記録ごと消す |
| 🟡 低 | `lib/hook_io.py` | `split_commands` が空の引数と、引用符の中の `;` で区切る |
| 🟡 低 | `lib/transcripts.py` | `tail_lines` が `splitlines()` で U+2028 の所で行を割る |
| 🟡 低 | `lib/md_blocks.py` | `table_under` が、コードの囲みの中の `#` で表を切る |
| 🟡 低 | `hooks/pr-gate.py` | xargs・eval の先を見ない。`--tags` の扱いが docs/testing.md と合わず、時間切れの時に通す |
| 🟡 低 | `skills/pr-prune/scripts/prune-merged.sh` | worktree add が落ちると一時フォルダが残る。外付けのボリュームが外れていると DerivedData を消す |
| 🟡 低 | `skills/ui-snapshot/scripts/render-snapshots.sh` | 描く前に前の PNG を消す。強制終了の後のロックが残る |
| 🟡 低 | `skills/config-learn/scripts/collect-corrections.py` | JSON の null で落ちる所がある。count-tokens.py も同じ |
| 🟡 低 | `skills/config-learn/scripts/collect-corrections.py` | toolUseID の無い知らせを、月に 1 回に潰して数える |
| 🟡 低 | `skills/store-report/scripts/fetch-ratings.py` | 10 ページで黙って打ち切る |
| 🟡 低 | `skills/app-plan/scripts/search-apps.py` | 0 件の時に何も出さない |
| 🟡 低 | `skills/pr-create/scripts/route-pr.sh` | 本文を全部 URL に入れる |
| 🟡 低 | `skills/store-release/scripts/check-privacy.py` | Pods・build の中の Swift も読む |
| 🟡 低 | `skills/app-init/scripts/create-app.sh` | `find | head -1` が pipefail の下で SIGPIPE で止まりうる |
| 🟡 低 | `hooks/rules-detect-bash-edits.py` | tool_use_id が無いと状態のファイル名が全部同じになる |
| 🟡 低 | `scripts/config-audit.py` | `check_links` がコードの囲みの中も見る |

### 処理と速さ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `scripts/config-audit.py`・`hooks/docs-check.py` | 500 行を超える。検査の種類ごとに lib へ分ける |
| 🟡 低 | `hooks/rules-detect-bash-edits.py` | ls や cat などの読むだけのコマンドでも、`git status` を 2 回走らせる |
| 🟡 低 | `hooks/rules-require-read.py` | 編集のたびに会話の記録を最大 32MB 読み直す。読んだ所を覚えて続きだけ読む |
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
| 🟠 中 | `tests/config-audit.sh` | NG のケースで終了コードを見ない |
| 🟠 中 | `tests/pr-gate.sh` | 利用者の `CC_HOOKS_OFF`・`CC_UI_*`・`CC_STORE_*` を受け継ぐ |
| 🟠 中 | `scripts/config-audit.py` | skills・agents・rules の frontmatter と settings の検査の分岐にテストが無い |
| 🟠 中 | `tests/ui-snapshot.sh` | 描けた時の道を通らない。store-report の表の値、app-plan の成功も見ない |
| 🟠 中 | `skills/pr-create/scripts/classify-diff.sh` | 200 行の境目と、hooks/ 以外の risky のパターンにテストが無い |
| 🟠 中 | `tests/pr-fix.sh` | READ の権限、no checks reported の分岐にテストが無い |
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
| 🟡 低 | `tests/lib/fixtures.sh` | commit で commit.gpgsign を切らない |
| 🟡 低 | `tests/config-audit.sh` | expect_audit を 69 回、毎回リポジトリ全体を検査するので遅い。docs-check・pr-gate も同じ |
| 🟡 低 | `tests/store-release.sh` | 内部の関数を差し替える。store-reply・store-report も同じ |
| 🟡 低 | `tests/config-audit.sh` | docs/improvements.md などの文言に頼る置き換えがある |
| 🟡 低 | `tests/ctx-limit-read.sh` | 30_000 などの上限ちょうどが通るテストが無い。docs-check・swift-style-check も同じ |

### 検査にする案

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `scripts/config-audit.py` | 例外の時に NG の行が出ない main を見つける |
| 🟠 中 | `scripts/config-audit.py` | SKILL.md の手順のコマンドと allowed-tools を照らし合わせる |
| 🟠 中 | `scripts/config-audit.py` | `tests/app-init.sh` などの `python3 -c` を対象にする |
| 🟡 低 | `docs/testing.md` | 上限ちょうどが通るテストを置く、を決まりに書く |

## ⚠️ 直さないと決めたこと

調べ直しで出ても、次のものは指摘にしない。

| 中身 | 理由 |
| --- | --- |
| statusLine を足す | 人が要らないと決めた |
| `run-check.sh` の古いロックの競合を直す | mkdir と rmdir だけでは、競合を残さずに直せない |
| `make test` を並べて走らせる | 人が見送ると決めた |
| bash 5.2 で確かめる | 手元の bash が 3.2 だけで、確かめる場所が無い |
| `docs-section.sh`・`rules-detect-bash-edits.py` の改名 | 人が打つ名前なので、慣れた名前を残す |
| `make test` と `make test *` の許可の重なりを 1 つにする | 引数の無い呼び出しに `*` が当たるかを確かめられない |
| `run-check.sh`・`hooks/run.sh` の改名 | 参照が 30 件近くあり、変える益が小さい |
| `find-simulator.sh` の写しを 1 つにする | ひな形のアプリが単独で動くように、写しを持つ。同じかはテストで見る |
| lib の `.sh` と `.py` をフォルダで分ける | `source` のパスが 12 か所で変わり、益が小さい |
| 前置きの文を機械で止める | 要る前置きと要らない前置きを、文字だけでは分けられない |
| 「時」を使わず、ひらがなの書き方にそろえる | 「時」を止めると、「時間」「時刻」まで当たる |
