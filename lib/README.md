# lib

フック・スクリプト・スキルの入口から読まれる中身を置く。直す時の決まりは [development.md](../docs/config/development.md) にある。

## 🏷️ 名前の頭

直下には、持ち主が複数の共通の処理を置き、名前の頭でまとめる。持ち主が 1 つの中身は、1 本でも持ち主の名前の子フォルダに置く。

| 名前の頭 | まとまり |
| --- | --- |
| `config_audit/` | [config-audit.py](../bin/config-audit.py) だけが読む中身。`check_` で始まる関数が、検査として走る |
| `config_install/` | [config-install.sh](../bin/config-install.sh) だけが読む中身 |
| `docs_check/` | [docs-check.py](../dotclaude/hooks/docs-check.py) だけが読む中身 |
| `docs_section/` | [docs-section.sh](../bin/docs-section.sh) だけが読む中身 |
| `hook_` | フックの共通の処理 |
| `md_` | Markdown の読み方 |
| `store_`・`swift_` | その分類の共通の処理 |
| 無し | 分類をまたぐ共通の処理 |

## 📦 ファイル

使う所と関数の名前は、モジュールの名前を `git grep` で探す。

| ファイル | 中身 |
| --- | --- |
| [build_log.sh](build_log.sh) | ビルドや確認のログから、エラーと失敗の行を重ねずに出す |
| [config_audit/agents.py](config_audit/agents.py) | エージェントと rules の検査 |
| [config_audit/code.py](config_audit/code.py) | シェルと Python の書き方、lib を読む行、bin の入口の検査 |
| [config_audit/docs.py](config_audit/docs.py) | README の形、リンク、パス、台帳、語の使い方、文書の決まりの検査 |
| [config_audit/files.py](config_audit/files.py) | 追跡しているファイルの一覧と読み込み、名前の付け方の表の読み方 |
| [config_audit/layout.py](config_audit/layout.py) | 置ける場所、分ける合図の上限、入れる処理の検査 |
| [config_audit/names.py](config_audit/names.py) | 名前の頭と動詞、lib の持ち主、環境変数、テストと対象の対応の検査 |
| [config_audit/settings.py](config_audit/settings.py) | settings のフックの呼び方と登録、許可とフックの並びの検査 |
| [config_audit/skills.py](config_audit/skills.py) | スキルの項目、節、参照先、許可、使われていないスクリプトの検査 |
| [config_audit/templates.py](config_audit/templates.py) | ひな形が呼ぶファイル、置き換える印、ひな形の CLAUDE.md の検査 |
| [config_install/settings.jq](config_install/settings.jq) | 今の settings.json に、入れるフックと許可を混ぜた案を作る |
| [dates.py](dates.py) | 日本時間、月の形、記録の日時の月 |
| [docs_check/headings.py](docs_check/headings.py) | 見出しと目次の検査 |
| [docs_check/rows.py](docs_check/rows.py) | 文・箇条書き・表の行ごとの検査 |
| [docs_section/sections.py](docs_section/sections.py) | 見出しを読み、節を切り出す |
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
