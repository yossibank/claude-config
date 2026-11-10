# claude-config

Claude Code の全リポジトリに共通の決まりを、`~/.claude` に配るリポジトリ。

## 作業の進め方

| 場面 | 決まり |
| --- | --- |
| 確認 | `make verify` を通す。コマンドの中身は `docs/config/testing.md` にある |
| 入れ直す | `dotclaude/settings.json` を変えたら、`config-install.sh` で差分を見る |

## 構成

最上位は、行き先で分ける。

| 置く物 | 置き場所 |
| --- | --- |
| `~/.claude` に配るもの | `dotclaude/`。中の形は `~/.claude` と同じにする |
| 入口から読まれる中身 | `lib/` |
| 人が打つスクリプト | `scripts/` |
| テスト | `tests/` |
| 文書 | アプリの文書は `docs/app/`、claude-config の文書は `docs/config/` |

`docs/app/` の文書と `dotclaude/` の中は、アプリのリポジトリから名前で指される。名前を変えたら、app-init のひな形を同じ commit で直す。作り済みのアプリには、直す PR を同時に出す。

名前の付け方・フォルダの分け方・足し方は、`docs/config/development.md` に従う。
