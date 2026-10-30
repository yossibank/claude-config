# claude-config を直す時の決まり

> [!NOTE]
> claude-config のフック・スクリプト・スキルを足したり直したりする時の決まりが分かる。
> 名前の付け方・スクリプトの書き方・共通の処理・確かめ方・スクリプト・足し方がある。
> 使い方と入れ方は [README](../README.md) にある。

## 🏷️ 名前の付け方

名前は、頭に `<分類>-` を付けてそろえる。フォルダの中を名前の順に並べると、分類ごとにまとまる。分類は、フォルダをまたいで同じ接頭語を使う。

| 対象 | 形 | 例 |
| --- | --- | --- |
| スキル | `<分類>-<すること>` | `pr-create`、`ctx-handoff` |
| フック | `<分類>-<すること、または名詞>.py`。イベントは settings.json に書く。`.py` 以外は `run.sh` だけを置く | `docs-check.py`、`pr-gate.py` |
| rules | `<分類>-<範囲>.md` | `swift-core.md` |
| scripts | `<分類>-<すること、または名詞>.sh`・`.py`・`.jq` | `docs-section.sh`、`config-audit.py` |
| スキルのスクリプト | 動詞を先に、`<すること>[-<対象>]` | `check-listing.py`、`create-worktree.sh` |
| lib | 中身の名詞を `snake_case` にする。Python の import で読める形に、`.sh` もそろえる | `hook_io.py`、`build_log.sh` |
| tests/lib | 中身の名詞を `snake_case` の `.sh` にする | `assert.sh`、`fixtures.sh` |
| エージェント | 役割の名詞（`-er`） | `explorer` |
| output style | 返す形の名詞 | `report.md` |
| 環境変数 | `CC_[<分類>_]<中身>`。分類は接頭語の表の名前を大文字にする | `CC_UI_DEVICE`、`CC_APPS_DIR` |
| ひな形の印 | スクリプトが置き換える所は `__<名前>__` にし、`replace-placeholders.py` の tokens に入れる。人が書く所は `<中身>` | `__App__`、`<名前>` |
| 外の道具が読むファイル | 道具が決めた名前のままにし、この表の形にしない | `ios/license_plist.yml`、`store-release/templates/ja/*.txt` |

### 接頭語の表

分類は、次の表から選ぶ。表に無い接頭語と使う所の違う接頭語は、config-audit が `NG` にする。新しい分類が要る時は、行を足してから名前を付ける。

| 接頭語 | 分類 | 使う所 |
| --- | --- | --- |
| `app-` | 企画・立ち上げ | skills |
| `code-` | コード全般 | rules、skills |
| `config-` | claude-config 自体の手入れ | skills、scripts |
| `ctx-` | 文脈とトークンの管理 | skills、hooks |
| `docs-` | 文書 | rules、skills、hooks、scripts |
| `pr-` | PR | skills、hooks |
| `rules-` | rules を読ませる | hooks |
| `shell-` | シェルスクリプト | hooks |
| `store-` | App Store への公開と数字 | skills |
| `swift-` | Swift | rules、hooks |
| `ui-` | 見た目と動きの確認 | skills |

### 動詞の表

スキルのスクリプトの頭の動詞は、次の表から選ぶ。表に無い動詞は config-audit が `NG` にするので、行を足してから名前を付ける。

| 動詞 | すること |
| --- | --- |
| `add`・`create` | 足す、作る |
| `collect` | 手元の記録（会話の記録など）から集める |
| `fetch` | 外（App Store などの API）から取ってくる |
| `find`・`list`・`search` | 手元から合うものを 1 つ出す、並べる、検索する |
| `check`・`classify`・`count`・`hash` | 確かめる、分ける、数える、指紋を取る |
| `record`・`render`・`take`・`tile`・`write` | 録る、描く、撮る、並べる、書く |
| `archive`・`prune`・`replace`・`route`・`run` | アーカイブを作る、片付ける、置き換える、振り分ける、走らせる |
| `send` | 外に送る |

### そろえる語

同じものを指す語は、次の表の左の語にそろえる。右の語は config-audit が `NG` にする。

| 使う語 | 使わない語 |
| --- | --- |
| ワークツリー | 作業場所 |
| commit | コミット |
| スキル | skill |
| 差分の重さ | 確認の重さ |
| そろえる | 揃える |
| 時 | とき |

## 📏 スクリプトの書き方

スクリプトは、読み込まれた時に何も実行せず、結果を同じ形で返す。`make verify` の config-audit が、外れた書き方を `NG` にする。

| 対象 | 決まり |
| --- | --- |
| Python | 処理は `main()` に入れ、末尾を `if __name__ == "__main__":` にする。`assert` は使わない |
| シェル | スキルと `scripts/` の `.sh` は、2 行目を `set -euo pipefail` にする。終了コードを受ける所は `\|\| status=$?` で受ける |
| 言語を混ぜない | `.sh` の中に `python3 -c` を書かない。JSON は jq で読み、長い処理は `.py` に分ける |
| 結果 | stdout に `OK`・`NG` で始まる行で出す。失敗したら終了コード 1 で終える |
| 引数 | 足りない時は `[[ $# -ge N ]]` で確かめ、`NG` を出す。`${N:?}` は使わない |
| 知らせ | 失敗ではない知らせは stderr に出す |
| フック | 終了コード 2 で返す文は stderr に、JSON で返すものは stdout に出す |
| 共通の処理 | フックとスクリプトの共通の処理は `lib/` に置き、`sys.path.insert` か `source` で読む。ワークツリーの置き場所は lib にだけ書く |
| フックの登録 | 検査のフックは `if` で拡張子を絞り、当たらないファイルでは起動しない。`Edit(//**/*.md)` は Write に当たらないので、`Write(//**/*.md)` も並べる |
| 編集の matcher | 編集を受けるフックの matcher は、`hook_io` の `FILE_EDIT_TOOLS` と同じ道具を並べる |

## 📦 共通の処理

フックとスクリプトが共通で使う処理は、`lib/` に置く。使う所は、モジュールの名前を `git grep` で探す。

| ファイル | 中身 |
| --- | --- |
| [lib/app_store.py](../lib/app_store.py) | App Store の検索とレビューの読み方、失敗の理由と途中までの知らせの文。App Store Connect API のキーと署名、アプリの一覧、返信案のファイルの読み方 |
| [lib/build_log.sh](../lib/build_log.sh) | ビルドや確認のログから、エラーと失敗の行を重ねずに出す `show_errors` |
| [lib/dates.py](../lib/dates.py) | 日本時間、月の形、記録の日時の月 |
| [lib/git.py](../lib/git.py) | タイムアウト付きの git と、リポジトリの根。根は、まだ無いフォルダからも在る親をたどって探す |
| [lib/git.sh](../lib/git.sh) | リポジトリの根（`use_repo`）、git のフォルダの中のパス（`git_file`）、ワークツリーの置き場所。既定のブランチと、GitHub での書き込みの権限 |
| [lib/hook_io.py](../lib/hook_io.py) | 入力の JSON と対象のパス、コマンドの区切りと頭の読み飛ばし、止める時の出し方。止めたフックの判定、編集する道具の名前、例外でも止める門番の入口 `run_gate` |
| [lib/hook_messages.py](../lib/hook_messages.py) | フックが止める時の文の書き出し。config-learn が止めた回数を数える時の目印にもなる |
| [lib/hook_state.py](../lib/hook_state.py) | 状態フォルダの場所と名前、作る時の古い状態ファイルの掃除 |
| [lib/loader.py](../lib/loader.py) | ファイルの場所から .py を読み込む |
| [lib/md_blocks.py](../lib/md_blocks.py) | Markdown の frontmatter、見出しの下の表、コードの囲みの見分け方 |
| [lib/md_doc.py](../lib/md_doc.py) | 文書を行と種類に分けた形と、rules の表からの絵文字・README の順の読み方。`md_blocks` の上に作る |
| [lib/script_io.py](../lib/script_io.py) | `NG` を出して止める `fail` と、月の引数を確かめる `require_month`。一時ファイルを経て JSON を書く `write_json` |
| [lib/transcripts.py](../lib/transcripts.py) | 会話の記録の読み方と、ワークツリーのパスからリポジトリの名前を出す `repo_of` |

ほかのスキルのスクリプトは、持ち主のスキルに置いたまま使う。スキルからは `${CLAUDE_SKILL_DIR}/../<スキル>/scripts/` で呼ぶ。フックからは、リポジトリの根からの `skills/<スキル>/scripts/` で呼ぶ。

## 🧪 確かめ方

claude-config を変えたら、`make verify` を通す。

> [!IMPORTANT]
> CI は置かない。PR は、Claude が pr-create の確認で `make verify` を通してから作る。

| コマンド | 確かめること |
| --- | --- |
| `make verify` | `make audit` と `make test` を順に走らせる |
| `make audit` | config-audit.py で、文書と名前と書き方の決まり |
| `make test` | `tests/*.sh` の全部で、フックとスクリプトの振る舞い |
| `make test-<対象>` | `tests/<対象>.sh` の 1 本だけ |

### テスト

テストの対象は、フックの `.py`、`scripts/` のファイル、`scripts/` を持つスキルである。テストの名前は、対象の拡張子を除いた名前にする。config-audit が、テストと対象が 1 対 1 でないと `NG` にする。

テストは `tests/<対象>.sh` に置く。1 本ずつが確かめることは、次のとおりである。

| テスト | 確かめること |
| --- | --- |
| `tests/app-init.sh` | ひな形の印を置き換え、一時のフォルダに新しいアプリを作れるか |
| `tests/app-plan.sh` | 通信せずに、引数の NG と通信できない時の NG を出すか |
| `tests/config-audit.sh` | わざと壊した写しで、config-audit が違反を見逃さないか |
| `tests/config-install.sh` | 一時の HOME で、入れ方がほかのフックと実体を残すか。入れた先からフックとスキルのスクリプトが動くか |
| `tests/config-learn.sh` | フックが止めた回数を、config-learn が数えられるか |
| `tests/ctx-limit-read.sh` | 大きいファイルを範囲なしで読む時だけ止めるか |
| `tests/ctx-report.sh` | 作り物の会話の記録から、月ごとのトークンを数えられるか |
| `tests/ctx-suggest-clear.sh` | 文脈が大きい時に、同じ段で 1 回だけ区切りを勧めるか |
| `tests/docs-check.sh` | 文書の決まりに外れた時に止め、合う時は通すか |
| `tests/docs-polish.sh` | 文字だけが続く節を見つけ、表・図・コードの囲みのある節は通すか |
| `tests/docs-section.sh` | 見出しの一覧と節の出し方 |
| `tests/pr-create.sh` | ワークツリー・PR の重さ・本文・出し方を決められるか。偽の gh と作り物のリポジトリで試す |
| `tests/pr-fix.sh` | 偽の gh で、直すものを集められるか |
| `tests/pr-gate.sh` | 確認の記録が無い時や、確認の後に変えた時に push と PR を止めるか |
| `tests/pr-prune.sh` | 偽の gh と作り物のリポジトリで、消してよいものだけを消すか。積んだブランチを main に載せ直し、ぶつかる時は残すか |
| `tests/rules-detect-bash-edits.sh` | Bash での書き換えを見つけるか。git だけのコマンドと、Bash の間に Edit・Write で変えたファイルを数えないか |
| `tests/rules-require-read.sh` | 当たる rules を読む前の編集を止め、圧縮やサブエージェントでも数え違えないか |
| `tests/shell-check.sh` | `.sh` の構文と、変数の直後の全角で止めるか |
| `tests/store-release.sh` | 掲載情報の字数と形、プライバシーの申告の足りなさを確かめられるか。アーカイブの失敗をログの error の行で知らせるか |
| `tests/store-reply.sh` | 通信せずに試す。引数の NG・返信済みのレビューの除外・`--dry-run` で送らないこと・送る JSON の形を確かめる |
| `tests/store-report.sh` | 通信せずに、引数の NG と売上の表の集計を出せるか。取れなかった数字を WARNING に書くか |
| `tests/swift-format.sh` | `.swiftformat` が無ければ何もしないか |
| `tests/ui-record.sh` | 偽の ffmpeg と偽の xcrun で、コマ数と出力先を決められ、引数の NG を出すか |
| `tests/ui-snapshot.sh` | パッケージにテストのターゲットを足せ、引数や出力先が違う時は走らせる前に NG にするか |

テストが共通で使う処理は、`tests/lib/` に置く。

| ファイル | 中身 |
| --- | --- |
| [tests/lib/assert.sh](../tests/lib/assert.sh) | 一時のフォルダ、`OK`・`NG` の出し方、出力が型に合うかを確かめる `match`、結果の数え方 |
| [tests/lib/fixtures.sh](../tests/lib/fixtures.sh) | 作り物のリポジトリと、偽の gh・偽のコマンド（`fake_command`） |
| [tests/lib/hooks.sh](../tests/lib/hooks.sh) | フックのテストの作り物のアプリと、フックへの入力の作り方 |

## 📜 スクリプト

入れる時、確かめる時、文書を読む時に、次のスクリプトを使う。

| スクリプト | 呼ぶ時 | すること |
| --- | --- | --- |
| [scripts/config-audit.py](../scripts/config-audit.py) | `make audit` の時 | README の表・図・参照先と名前の食い違い、文書とスクリプトの書き方の違反を見る |
| [scripts/config-install.sh](../scripts/config-install.sh) | 入れる時 | `~/.claude` からリンクを張り、settings.json の案を作る |
| [scripts/docs-section.sh](../scripts/docs-section.sh) | 文書を読む時 | 見出しの一覧か、指定した節だけを出す |
| [scripts/docs-section.py](../scripts/docs-section.py) | docs-section.sh から | docs-section.sh の中身。見出しを読み、節を切り出す |

## 🚀 足し方

スキル・フック・スクリプトを足す時は、次の順に進める。

1. 名前の頭を [接頭語の表](#接頭語の表) で確かめる。スキルのスクリプトは、頭の動詞を [動詞の表](#動詞の表) で確かめる。
2. 本体を置く。スキルは `skills/<名前>/SKILL.md`、フックは `hooks/<名前>.py`、スクリプトは `scripts/` に置く。
3. フックは、`settings/settings.json` にも登録する。書き方は [スクリプトの書き方](#-スクリプトの書き方) の表にある。
4. `tests/<名前>.sh` を足し、[テスト](#テスト) の表に行を足す。
5. README の表に行を足す。スキルは、README の使う順の図にも足す。
6. [確かめ方](#-確かめ方) の `make verify` を通す。
