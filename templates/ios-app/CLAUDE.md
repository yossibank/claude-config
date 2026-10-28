# __App__

個人開発の iOS アプリ「__DisplayName__」。人間向けの入口は [README.md](README.md)。

## 作業の進め方

変更したら `make verify` を通す。出力は成否と失敗の箇所だけで、失敗した時は全ログのパスが最後の行にある。テストは CI で走らせず、PR を作る前に手元で `make test` を 1 回通す。文書だけの PR では走らせない。

見た目は、claude-config の `ui-snapshot` のスキルで描いて確かめる。描く場合は `.claude/snapshots/<セット>/` に置き、`make snapshot SNAPSHOT=<セット>` で描く。

## 構成

構成は、共通の形（`~/Applications/AI/claude-config/docs/architecture-ios.md`）に従う。外れたら `docs/architecture.md` を足し、外れた点だけを書く。

## 文書

作業ごとに、先に読む文書と、終えたら直す文書が決まっている。

| 作業 | 先に読む | 終えたら直す |
| --- | --- | --- |
| 機能・画面を足す | [overview](docs/overview.md)、[roadmap](docs/roadmap.md) | overview、roadmap |
| 作る順番の 1 段を終える | [roadmap](docs/roadmap.md) | roadmap の状態 |
| 構成を共通の形から外す | 共通の形 | `docs/architecture.md` |
