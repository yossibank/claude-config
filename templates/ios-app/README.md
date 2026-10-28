# __DisplayName__

<何のアプリかを 1 文で>

## 📚 文書

文書は、次のとおりに分かれる。

| 知りたいこと | 文書 |
| --- | --- |
| 何を作るか | [docs/overview.md](docs/overview.md) |
| 作る順番と画面 | [docs/roadmap.md](docs/roadmap.md) |

## 🚀 動かし方

Xcode と Homebrew が要る。最初に 1 回、道具を入れる。

```sh
make setup
```

ふだんは、次のコマンドを使う。

| コマンド | すること |
| --- | --- |
| `make open` | Xcode でワークスペースを開く |
| `make verify` | Kit のテストと iOS のビルドを通す |
| `make test` | テストプランをシミュレーターで走らせる |
| `make snapshot SNAPSHOT=<セット>` | `.claude/snapshots/<セット>` の画面を PNG に描く |
| `make format` | SwiftFormat で整える |
| `make licenses` | 設定アプリに出すライセンスの一覧を作り直す |
