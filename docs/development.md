# claude-config を直す時の決まり

> [!NOTE]
> claude-config のフック・スクリプト・スキルを足したり直したりする時の決まりが分かる。
> 確かめ方とテストは [testing.md](testing.md)、部品の一覧は [components.md](components.md) にある。

## 🏷️ 名前の付け方

名前は、頭に `<分類>-` を付けてそろえる。スキル・フック・rules・scripts は、フォルダの中を名前の順に並べると分類ごとにまとまる。分類は、フォルダをまたいで同じ接頭語を使う。

| 対象 | 形 | 例 |
| --- | --- | --- |
| スキル | `<分類>-<すること>` | `pr-create`、`ctx-handoff` |
| フック | `<分類>-<すること、または名詞>.py` | `docs-check.py`、`pr-gate.py` |
| フックのフォルダ | `.py` 以外は `run.sh` だけを置く。イベントは `settings/settings.json` に書く | `hooks/run.sh` |
| rules | `<分類>-<範囲>.md`。範囲は、言語・読み手・主題のどれか | `swift-core.md`、`code-comments.md` |
| scripts | `<分類>-<すること、または名詞>.sh`・`.py`・`.jq` | `docs-section.sh`、`config-audit.py` |
| スキルのスクリプト | 動詞を先に、`<すること>[-<対象>]` | `check-listing.py`、`create-worktree.sh` |
| scripts の拡張子違いの組 | `.sh` が入口で、同じ名前の `.py`・`.jq` はその中身 | `docs-section.sh` と `docs-section.py` |
| スクリプトの置き場所 | そのスキルだけが呼ぶものは `skills/<名前>/scripts/` に置く。人・フック・複数のスキルが呼ぶ共通の道具は `scripts/` に置く | `scripts/docs-section.sh` |
| ひな形のフォルダ | `skills/<名前>/templates/<単位>/`。単位は、アプリ 1 本・言語・セットのどれか | `templates/ios-app/`、`templates/ja/` |
| docs/ の文書 | 名詞の kebab-case の `.md`。主題を分ける時は `<主題>-<分類>.md` | `setup.md`、`architecture-ios-naming.md` |
| lib | 中身の名詞を `snake_case` にする。Python の import で読める形に、`.sh` もそろえる | `hook_io.py`、`build_log.sh` |
| tests/lib | 中身の名詞を `snake_case` の `.sh` にする | `assert.sh`、`fixtures.sh` |
| エージェント | 役割の名詞（`-er`） | `explorer` |
| output style | 返す形の名詞 | `report.md` |
| 環境変数 | `CC_[<分類>_]<中身>`。分類は接頭語の表の名前を大文字にする | `CC_UI_DEVICE`、`CC_APPS_DIR` |
| ひな形の印（置き換える所） | `__<名前>__` にし、`replace-placeholders.py` の tokens に入れる | `__App__` |
| ひな形の印（人が書く所） | `<中身>` にする | `<名前>` |
| 外の道具が読むファイル | 道具が決めた名前のままにし、この表の形にしない | `ios/license_plist.yml`、`store-release/templates/ja/*.txt` |

### 並べる順

表と一覧は、次の順に並べる。

| 対象 | 順 |
| --- | --- |
| docs の表と一覧 | 名前の順。手順・段階・重さのように順に意味がある時は、その順 |
| `settings/settings.json` の許可 | コマンドの名前の順。同じコマンドは引数の順 |
| `settings/settings.json` のフック | イベントは処理の順（Pre → Post）、matcher と、その中のフックは名前の順 |

### 接頭語の表

分類は、次の表から選ぶ。表に無い接頭語と使う所に合わない接頭語は、config-audit が `NG` にする。新しい分類が要る時は、行を足してから名前を付ける。

| 接頭語 | 分類 | 使う所 |
| --- | --- | --- |
| `app-` | 企画・立ち上げ | skills |
| `code-` | コード全般 | rules、skills |
| `config-` | claude-config 自体の手入れ | skills、scripts |
| `ctx-` | 文脈とトークンの管理 | skills、hooks |
| `docs-` | 文書 | rules、skills、hooks、scripts |
| `pr-` | PR | skills、hooks |
| `rules-` | rules を読ませる、rules を避けた書き換えを見つける | hooks |
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
| `find`・`list` | 手元から合うものを 1 つ出す、並べる |
| `search` | 外の API に検索を頼み、合うものを並べる |
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
| 知らせ | スクリプトの、失敗ではない知らせは stderr に出す |
| フック | 終了コード 2 で返す文は stderr に、JSON で返すものは stdout に出す。止めない知らせは、終了コード 0 の stderr が見えないので `notify` で出す |
| 共通の処理 | フックとスクリプトの共通の処理は `lib/` に置き、`sys.path.insert` か `source` で読む。ワークツリーの置き場所は lib にだけ書く |
| フックの登録 | 検査のフックは `if` で拡張子を絞り、当たらないファイルでは起動しない。`Edit(//**/*.md)` は Write に当たらないので、`Write(//**/*.md)` も並べる |
| 編集の matcher | 編集を受けるフックの matcher は、`hook_io` の `FILE_EDIT_TOOLS` と同じ道具を並べる |

## 📦 共通の処理

フックとスクリプトが共通で使う処理は、`lib/` に置く。使う所は、モジュールの名前を `git grep` で探す。

| ファイル | 中身 |
| --- | --- |
| [lib/app_store.py](../lib/app_store.py) | App Store の検索とレビューを読み、失敗の理由と途中までの知らせの文を作る。ページ送りの `paginate`・`asc_pages` と、アプリの ID の確かめも持つ。App Store Connect API のキーと署名、アプリの一覧、返信案のファイルも扱う |
| [lib/audit_code.py](../lib/audit_code.py) | config-audit の、シェルと Python の書き方、settings、ひな形、ワークツリーの置き場所の検査 |
| [lib/audit_docs.py](../lib/audit_docs.py) | config-audit の、README の形、リンク、見出しの参照先、パス、台帳、文書の決まりの検査 |
| [lib/audit_files.py](../lib/audit_files.py) | config-audit が使う、追跡しているファイルの一覧、読み込み、コードの囲みの外の行、## の見出し |
| [lib/audit_names.py](../lib/audit_names.py) | config-audit の、名前の頭と動詞、語の使い方、テストと対象の対応の検査 |
| [lib/audit_skills.py](../lib/audit_skills.py) | config-audit の、スキル、エージェント、rules、ひな形の CLAUDE.md の検査 |
| [lib/build_log.sh](../lib/build_log.sh) | ビルドや確認のログから、エラーと失敗の行を重ねずに出す `show_errors` |
| [lib/dates.py](../lib/dates.py) | 日本時間、月の形、記録の日時の月 |
| [lib/docs_headings.py](../lib/docs_headings.py) | docs-check の、見出しと目次の検査 |
| [lib/docs_rows.py](../lib/docs_rows.py) | docs-check の、文・箇条書き・表の行ごとの検査 |
| [lib/git.py](../lib/git.py) | タイムアウト付きの git、リポジトリの根、ワークツリーの置き場所（`WORKTREES` など）。根は、まだ無いフォルダからも在る親をたどって探す |
| [lib/git.sh](../lib/git.sh) | 根（`use_repo`）、git のフォルダの中のパス（`git_file`）、ワークツリーの置き場所。分かれ目・変えたファイル・既定のブランチ・書き込みの権限 |
| [lib/hook_io.py](../lib/hook_io.py) | 入力の JSON と対象のパス、コマンドの区切りと頭の読み飛ばし。止める時と止めない知らせ（`notify`）の出し方、編集する道具の名前、例外でも止める入口 `run_gate`、例外を知らせて通す入口 `run_hook` |
| [lib/hook_messages.py](../lib/hook_messages.py) | フックが止める時の文の書き出し。config-learn が止めた回数を数える時の目印にもなる |
| [lib/hook_state.py](../lib/hook_state.py) | 状態フォルダの場所と名前、古い状態ファイルの掃除。掃除は 1 時間に 1 回で、フォルダの中の新しいファイルは残す |
| [lib/loader.py](../lib/loader.py) | claude-config の根（`ROOT`）と、場所を指して .py を読む処理 |
| [lib/md_blocks.py](../lib/md_blocks.py) | Markdown の frontmatter、見出し（`heading_of`）、見出しの下の表、コードの囲み |
| [lib/md_doc.py](../lib/md_doc.py) | 文書を行と種類に分けた形と、rules の表の絵文字・README の順（読めない表は `rule_problems`）。`md_blocks` の上に作る |
| [lib/script_io.py](../lib/script_io.py) | `NG` で止める `fail`・`run_main` と、結果の行を出す `finish`。引数を読む `require_month`・`split_dry_run`、JSON を書く `write_json` |
| [lib/swift_source.py](../lib/swift_source.py) | Swift のコードから、コメントと文字列（補間の中の入れ子も）の中身を空白にする `mask` |
| [lib/transcripts.py](../lib/transcripts.py) | 会話の記録の読み方とリポジトリの名前（`repo_of`）。ある日時より後の記録の一覧（`sessions_since` など）、続きだけを読む `lines_after` |
| [lib/worktree.sh](../lib/worktree.sh) | ブランチのワークツリーを探す `worktree_of` |

ほかのスキルのスクリプトは、持ち主のスキルに置いたまま、呼ぶ所に合わせた書き方で使う。

| 呼ぶ所 | 書き方 |
| --- | --- |
| スキル | `${CLAUDE_SKILL_DIR}/../<スキル>/scripts/` |
| フック | リポジトリの根からの `skills/<スキル>/scripts/` |

## 🚀 足し方

1. 名前の頭を [接頭語の表](#接頭語の表) で確かめる。スキルのスクリプトは、頭の動詞を [動詞の表](#動詞の表) で確かめる。
2. 本体を置く。スキルは `skills/<名前>/SKILL.md`、フックは `hooks/<名前>.py`、スクリプトは `scripts/` に置く。
3. フックは、`settings/settings.json` にも登録する。書き方は [スクリプトの書き方](#-スクリプトの書き方) の表にある。
4. `tests/<名前>.sh` を足し、[testing.md のテスト](testing.md#-テスト) の表に行を足す。
5. [components.md](components.md) か [skills.md](skills.md) の表に行を足す。スキルは、skills.md の使う順の図にも足す。
6. 文書を足したり書き換えたりする時は、[docs-core](../rules/docs-core.md)・[docs-human](../rules/docs-human.md)・[docs-app](../rules/docs-app.md) の決まりに従う。
7. [testing.md](testing.md#-動かし方) の `make verify` を通す。
