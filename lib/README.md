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

使う所と関数の名前は、モジュールの名前を `git grep` で探す。

| ファイル | 中身 |
| --- | --- |
| [build_log.sh](build_log.sh) | ビルドや確認のログから、エラーと失敗の行を重ねずに出す |
| [config_audit_code.py](config_audit_code.py) | シェルと Python の書き方、settings、ひな形の検査 |
| [config_audit_docs.py](config_audit_docs.py) | README の形、リンク、パス、台帳、文書の決まりの検査 |
| [config_audit_files.py](config_audit_files.py) | 追跡しているファイルの一覧と読み込み |
| [config_audit_names.py](config_audit_names.py) | 名前の頭と動詞、語の使い方、テストと対象の対応の検査 |
| [config_audit_skills.py](config_audit_skills.py) | スキル、エージェント、rules、ひな形の CLAUDE.md の検査 |
| [config_install.jq](config_install.jq) | 今の settings.json に、入れるフックと許可を混ぜた案を作る |
| [dates.py](dates.py) | 日本時間、月の形、記録の日時の月 |
| [docs_check_headings.py](docs_check_headings.py) | 見出しと目次の検査 |
| [docs_check_rows.py](docs_check_rows.py) | 文・箇条書き・表の行ごとの検査 |
| [docs_section.py](docs_section.py) | 見出しを読み、節を切り出す |
| [git.py](git.py) | タイムアウト付きの git、リポジトリの根、ワークツリーの置き場所 |
| [git.sh](git.sh) | リポジトリの根、ワークツリーの置き場所、ブランチと変えたファイルの調べ方 |
| [hook_io.py](hook_io.py) | フックの入力の読み方、止め方と知らせ方、例外を受ける入口 |
| [hook_messages.py](hook_messages.py) | フックが止める時の文の書き出し |
| [hook_state.py](hook_state.py) | 状態フォルダの場所と名前、古い状態ファイルの掃除 |
| [loader.py](loader.py) | claude-config の根と、場所を指して `.py` を読む処理 |
| [md_blocks.py](md_blocks.py) | Markdown の frontmatter、見出し、表、コードの囲み |
| [md_doc.py](md_doc.py) | 文書を行と種類に分けた形と、rules の表の読み方 |
| [script_io.py](script_io.py) | `NG` で止める入口、結果の行、引数の読み方、JSON の書き出し |
| [store_api.py](store_api.py) | App Store の検索とレビュー、App Store Connect API のキーと署名 |
| [swift_source.py](swift_source.py) | Swift のコードから、コメントと文字列の中身を空白にする |
| [transcripts.py](transcripts.py) | 会話の記録の読み方と、ある日時より後の記録の一覧 |
