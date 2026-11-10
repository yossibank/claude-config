# claude-config

claude-config だけで守る決まり。ルートの `CLAUDE.md` は全リポジトリの決まりなので、このリポジトリだけの事実はここに書く。

## 作業の進め方

| 場面 | 決まり |
| --- | --- |
| 確認 | `make verify` を通す。コマンドの中身は `docs/config-testing.md` にある |
| 足す・直す | 名前・スクリプトの書き方・足す手順は `docs/config-development.md` に従う |
| 入れ直す | `settings/` を変えたら、`scripts/config-install.sh` で差分を確かめる |

## 構成

| 置き場所 | 中身 |
| --- | --- |
| `CLAUDE.md` | 全リポジトリの決まり。claude-config だけの事実は書かない |
| `.claude/CLAUDE.md` | claude-config だけの決まり |
| `docs/architecture-*.md` | アプリのリポジトリが読む共通の構成。アプリから名前で指されるので、名前を変えない |
| `docs/config-*.md` | claude-config を直す時と調べ直す時の文書 |
