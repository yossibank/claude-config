# __App__

個人開発の iOS アプリ「__DisplayName__」。人間向けの入口は [README.md](README.md)。

## 作業の進め方

作業の確認は、次のコマンドで行う。

| コマンド | 走らせる時 | 出力 |
| --- | --- | --- |
| `make verify` | 変更したら毎回 | 成否と失敗の箇所。失敗した時は、ログのパスが最後の行にある |
| `make test` | PR を作る前に 1 回。文書だけの PR では走らせない | テストの結果。CI では走らせない |

見た目は、claude-config の `ui-snapshot` のスキルで確かめる。描く場合のセットはスキルに従って置き、`make snapshot SNAPSHOT=<セット>` で描く。

## 構成

構成は、claude-config の `docs/architecture-ios.md` の共通の形に従う。外れた時に足す文書は、claude-config の `rules/docs-app.md` に従う。

## 文書

作業ごとに、先に読む文書と、終えたら直す文書が決まっている。

| 作業 | 先に読む | 終えたら直す |
| --- | --- | --- |
| 機能・画面を足す | [overview](docs/overview.md)、[roadmap](docs/roadmap.md) | overview、roadmap |
| 作る順番の 1 段を終える | [roadmap](docs/roadmap.md) | roadmap の状態 |
| 構成を共通の形から外す | 共通の形 | `docs/architecture.md` |
