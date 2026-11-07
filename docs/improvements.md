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
| 🟠 中 | `hooks/swift-format.py` | Swift を編集するたびに mint を最大 60 秒待つ。縮めるか、非同期にするかを決める |
| 🟡 低 | `hooks/run.sh` | `CC_HOOKS_OFF` の知らない名前を、見えない stderr に出す。フックの JSON と 1 つにまとめる仕組みが要る |
| 🟡 低 | `hooks/pr-gate.py` | 確認が時間切れの時に通す。docs/components.md の「知らせて通す」と合わせて、止めるかを決める |

### 処理と速さ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟡 低 | `docs/development.md` の「結果」 | データを返すスクリプトは OK と NG を出さない。その形を決まりに書く |
| 🟡 低 | `skills/pr-create/scripts/hash-state.sh` | `git add -A` を確認のたびに 2 回走らせる |

### テスト

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `lib/app_store.py` | 署名の DER を読む処理にテストが無い |
| 🟠 中 | `tests/pr-fix.sh` | 偽の gh が完成した行を返し、未解決に絞る式が走らない |
| 🟠 中 | `tests/pr-prune.sh` | squash でないマージのテストに子のブランチが無く、空振りする |
| 🟠 中 | `scripts/config-audit.py` | skills・agents・rules の frontmatter と settings の検査の分岐にテストが無い |
| 🟠 中 | `tests/ui-snapshot.sh` | 描けた時の道を通らない。store-report の表の値、app-plan の成功も見ない |
| 🟠 中 | `skills/pr-create/scripts/classify-diff.sh` | 200 行の境目と、hooks/ 以外の risky のパターンにテストが無い |
| 🟠 中 | `tests/pr-fix.sh` | READ の権限、no checks reported の分岐にテストが無い |
| 🟡 低 | `tests/pr-prune.sh` | ls-remote が落ちた時に付け替えを見送る道に、テストが無い |
| 🟡 低 | `tests/rules-require-read.sh` | `tests/lib/hook_fixtures.sh` が HOME を分けない。`sleep 1` と date に頼る |
| 🟡 低 | `tests/pr-prune.sh` | 準備の失敗を `2>/dev/null` で消す |
| 🟡 低 | `tests/store-release.sh` | 字数の上限ちょうどが通るテストが無い。fixtures.sh を 2 度 source する |
| 🟡 低 | `tests/store-reply.sh` | 字数の上限ちょうどが通るテストが無い |
| 🟡 低 | `tests/ui-snapshot.sh` | iPhone 1 台で「先頭」を確かめていない |
| 🟡 低 | `tests/rules-detect-bash-edits.sh` | cd 先に `app/` が無い場合のテストが無い |
| 🟡 低 | `tests/lib/hook_fixtures.sh` | JSON を文字列で組んでいる |
| 🟡 低 | `tests/shell-check.sh` | 対象外の入力のテストが無い。`tests/swift-format.sh`・`tests/ctx-limit-read.sh` も同じ |
| 🟡 低 | `tests/lib/fixtures.sh` | commit で commit.gpgsign を切らない |
| 🟡 低 | `tests/config-audit.sh` | expect_audit を 69 回、毎回リポジトリ全体を検査するので遅い。docs-check・pr-gate も同じ |
| 🟡 低 | `tests/store-release.sh` | 内部の関数を差し替える。store-reply・store-report も同じ |
| 🟡 低 | `tests/config-audit.sh` | docs/improvements.md などの文言に頼る置き換えがある |
| 🟡 低 | `tests/ctx-limit-read.sh` | 30_000 などの上限ちょうどが通るテストが無い。docs-check・swift-style-check も同じ |

### 検査にする案

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `scripts/config-audit.py` | SKILL.md の手順のコマンドと allowed-tools を照らし合わせる |

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
