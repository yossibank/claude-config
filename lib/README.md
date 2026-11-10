# lib

フック・スクリプト・スキルの入口から読まれる中身を置く。直す時の決まりは [development.md](../docs/config/development.md) にある。

## 🏷️ 名前の頭

子フォルダは作らず、名前の頭でまとめる。持ち主が 1 つの中身は、持ち主の名前を `snake_case` にして頭に付ける。

| 名前の頭 | まとまり |
| --- | --- |
| `config_audit_` | [config-audit.py](../scripts/config-audit.py) だけが読む中身 |
| `config_install` | [config-install.sh](../scripts/config-install.sh) だけが読む中身 |
| `docs_check_` | [docs-check.py](../dotclaude/hooks/docs-check.py) だけが読む中身 |
| `docs_section` | [docs-section.sh](../scripts/docs-section.sh) だけが読む中身 |
| `hook_` | フックの共通の処理 |
| `md_` | Markdown の読み方 |
| `store_`・`swift_` | その分類の共通の処理 |
| 無し | 分類をまたぐ共通の処理 |

## 📦 ファイル

使う所は、モジュールの名前を `git grep` で探す。

| ファイル | 中身 |
| --- | --- |
| [build_log.sh](build_log.sh) | ビルドや確認のログから、エラーと失敗の行を重ねずに出す `show_errors` |
| [config_audit_code.py](config_audit_code.py) | config-audit の、シェルと Python の書き方、settings、ひな形、ワークツリーの置き場所の検査 |
| [config_audit_docs.py](config_audit_docs.py) | config-audit の、README の形、リンク、見出しの参照先、パス、台帳、文書の決まりの検査 |
| [config_audit_files.py](config_audit_files.py) | config-audit が使う、追跡しているファイルの一覧、読み込み、コードの囲みの外の行、## の見出し |
| [config_audit_names.py](config_audit_names.py) | config-audit の、名前の頭と動詞、語の使い方、テストと対象の対応の検査 |
| [config_audit_skills.py](config_audit_skills.py) | config-audit の、スキル、エージェント、rules、ひな形の CLAUDE.md の検査 |
| [config_install.jq](config_install.jq) | config-install.sh の中身。今の settings.json に、入れるフックと許可を混ぜた案を作る |
| [dates.py](dates.py) | 日本時間、月の形、記録の日時の月 |
| [docs_check_headings.py](docs_check_headings.py) | docs-check の、見出しと目次の検査 |
| [docs_check_rows.py](docs_check_rows.py) | docs-check の、文・箇条書き・表の行ごとの検査 |
| [docs_section.py](docs_section.py) | docs-section.sh の中身。見出しを読み、節を切り出す |
| [git.py](git.py) | タイムアウト付きの git、リポジトリの根、ワークツリーの置き場所（`WORKTREES` など）。根は、まだ無いフォルダからも在る親をたどって探す |
| [git.sh](git.sh) | 根（`use_repo`）、git のフォルダの中のパス（`git_file`）、ワークツリーの置き場所。分かれ目・変えたファイル・既定のブランチ・書き込みの権限・ブランチのワークツリー（`worktree_of`） |
| [hook_io.py](hook_io.py) | 入力の JSON と対象のパス、コマンドの区切り、止める時と知らせ（`notify`）の出し方、編集する道具の名前。入口は、例外でも止める `run_gate` と、知らせて通す `run_hook` |
| [hook_messages.py](hook_messages.py) | フックが止める時の文の書き出し。config-learn が止めた回数を数える時の目印にもなる |
| [hook_state.py](hook_state.py) | 状態フォルダの場所と名前、古い状態ファイルの掃除。掃除は 1 時間に 1 回で、フォルダの中の新しいファイルは残す |
| [loader.py](loader.py) | claude-config の根（`ROOT`）と、場所を指して .py を読む処理 |
| [md_blocks.py](md_blocks.py) | Markdown の frontmatter、見出し（`heading_of`）、見出しの下の表、コードの囲み |
| [md_doc.py](md_doc.py) | 文書を行と種類に分けた形と、rules の表の絵文字・README の順（読めない表は `rule_problems`）。`md_blocks` の上に作る |
| [script_io.py](script_io.py) | `NG` で止める `fail`・`run_main` と、結果の行を出す `finish`。引数を読む `require_month`・`split_dry_run`、JSON を書く `write_json` |
| [store_api.py](store_api.py) | App Store の検索とレビュー、失敗の理由、ページ送りの `asc_pages`。App Store Connect API のキーと署名、アプリの ID と一覧、返信案のファイルも扱う |
| [swift_source.py](swift_source.py) | Swift のコードから、コメントと文字列（補間の中の入れ子も）の中身を空白にする `mask` |
| [transcripts.py](transcripts.py) | 会話の記録の読み方とリポジトリの名前（`repo_of`）。ある日時より後の記録の一覧（`sessions_since` など）、続きだけを読む `lines_after` |
