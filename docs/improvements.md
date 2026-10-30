# 改善の台帳

> [!NOTE]
> claude-config の調べ直しで見つけて、まだ直していない改善と、直さないと決めたことが分かる。
> 調べ方は [config-review](../skills/config-review/SKILL.md) にある。

## 📏 台帳の書き方

台帳は、残っている改善と見送ったことだけを持つ。直した改善は行を消し、経緯は git の履歴に任せる。

| 場面 | すること |
| --- | --- |
| 調べ直した | 人が選ばなかった指摘を「残っている改善」に足す |
| PR で直した | 同じ PR で、その行を消す |
| 直さないと決めた | 「直さないと決めたこと」に、理由と一緒に移す |
| 前提が変わった | 見送りの理由が無くなったら、行を消す |

## 📝 残っている改善

分類ごとに、重さの高い順に並べる。直す時は、同じ分類の行をまとめて 1 本の PR にする。

### バグ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `skills/docs-polish/scripts/check-layout.py` | `docs/` を渡すと、その下の `docs/**` を探して「文書が無い」で NG になる |
| 🟡 低 | `hooks/run.sh` | `CC_HOOKS_OFF` の知らない名前を、見えない stderr に出す。フックの JSON と 1 つにまとめる仕組みが要る |

### 文書の読みやすさ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `README.md` の「フック」 | 冒頭の文が「止める」だけで、表の知らせるフックと整えるフックに合わない |
| 🟠 中 | `README.md` の「入れ方」 | 前提の NOTE が手順の間にある。前提を先に置き、手順を番号付きにする |
| 🟠 中 | `docs/development.md` | 上限の 15,000B に近い。「確かめ方」から下を `docs/testing.md` に分ける |
| 🟠 中 | `docs/architecture-ios.md` | 「make のコマンド」がフォルダの木の間にある。「動かし方」の節に出す |
| 🟡 低 | `docs/architecture-ios.md` の「パッケージ」 | Kit と App の違いが 3 か所に散らばる。節の頭に比べる表を置く |
| 🟡 低 | `docs/architecture-ios.md` | `0xdead10cc` の理由をアラートにし、依存の向きを太字にする |
| 🟡 低 | `README.md` の「入れ方」の手順 | 「実体」「2 つ」の指す先が読めない。settings.json が 1 文に 3 回出る |
| 🟡 低 | `README.md` のフックの表 | 列の名前の「動く時」と「当たる時」の違いが分からない |
| 🟡 低 | `docs/development.md` の表 | フックとひな形の印の行で、1 つのセルに別々の指示がある |
| 🟡 低 | 前置きだけの文 | `docs/development.md` のテストとスクリプトの表の前など。見出しで分かるので消す |

### 名前と並び

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | 表と一覧 | 並べる順の決まりが無い。`settings/settings.json` の許可とフックも名前の順でない |
| 🟡 低 | `skills/pr-fix/scripts/list-threads.sh` | GitHub から取ってくるので、動詞は `fetch` にする |
| 🟡 低 | `tests/lib/hooks.sh` | `hooks/` と名前が重なる。`hook_fixtures.sh` にする |
| 🟡 低 | `skills/ui-snapshot/templates/screen/` | SKILL.md の呼び名の「セット」に合わせて `set/` にする |
| 🟡 低 | `scripts/` の拡張子違いの組 | `.sh` が入口でほかが中身、という決まりを書き、検査にする |
| 🟡 低 | `docs/development.md` の動詞の表 | 1 行に動詞を詰めている。`search` は外の API も呼ぶので定義と合わない |
| 🟡 低 | `docs/development.md` のスクリプトの表 | `scripts/config-install.jq` の行が無い |
| 🟡 低 | `README.md` の「確かめ方」 | スクリプトの一覧が、`docs/development.md` の表と重なる |

### 処理と速さ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `scripts/config-audit.py`・`hooks/docs-check.py` | 500 行を超える。検査の種類ごとに lib へ分ける |
| 🟠 中 | `hooks/rules-detect-bash-edits.py` | ls や cat などの読むだけのコマンドでも、`git status` を 2 回走らせる |
| 🟠 中 | `hooks/rules-require-read.py` | 編集のたびに会話の記録を最大 32MB 読み直す。読んだ所を覚えて続きだけ読む |
| 🟡 低 | `skills/pr-prune/scripts/prune-merged.sh` | 載せ直しの処理を別のスクリプトに分け、グローバル変数をやめる |
| 🟡 低 | 見出しの読み方 | 4 か所で別々に読んでいる。`lib/md_blocks.py` に 1 つにまとめる |
| 🟡 低 | `hooks/ctx-suggest-clear.py` | 止まるたびに記録を 4MB 読む。後ろから読む処理を `lib/transcripts.py` に置く |
| 🟡 低 | `lib/hook_state.py` | 呼ぶたびに状態のフォルダを全部見て掃除する。1 時間に 1 回にする |
| 🟡 低 | `lib/app_store.py` | ページをめくるたびに openssl で署名する。期限までトークンを使い回す |
| 🟡 低 | Python の小さな重なり | OK と NG の集計が 3 か所、アプリ ID の確かめが 2 か所にある |
| 🟡 低 | `docs/development.md` の「結果」 | データを返すスクリプトは OK と NG を出さない。その形を決まりに書く |
| 🟡 低 | `tests/config-audit.sh` | 手助けの関数を `tests/lib/` に移し、`python3 -c` と `assert` をやめる |
| 🟡 低 | `skills/ui-snapshot/scripts/render-snapshots.sh` | 終了コードを `set +e` で受けている。決まりの `status=$?` の形にする |

### テスト

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `lib/app_store.py` の署名 | DER を読む処理にテストが無い |
| 🟠 中 | `tests/docs-check.sh` | 見出しの絵文字・冒頭の NOTE・アラートの数・バッジの検査にテストが無い |
| 🟡 低 | `tests/pr-prune.sh` | ls-remote が落ちた時に付け替えを見送る道に、テストが無い |
| 🟡 低 | `tests/lib/assert.sh` | 利用者の `~/.gitconfig` が効く。`GIT_CONFIG_GLOBAL` を `/dev/null` にする |
| 🟡 低 | `lib/git.py`・`lib/git.sh` | ワークツリーの置き場所を 2 か所で決めている。同じかを確かめるテストが無い |

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
