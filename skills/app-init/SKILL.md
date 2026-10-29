---
name: app-init
description: 新しい iOS アプリのリポジトリを、kakeibot の形のひな形から作る。app-plan で企画を書いた後や、人が新しいアプリを始める時に使う。
argument-hint: "<アプリの名前（英小文字）> <ストアの表示名>"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/create-app.sh *)
---

# アプリを立ち上げる

ビルドとテストが通る新しいアプリのリポジトリを、ひな形から作る手順。ひな形は `${CLAUDE_SKILL_DIR}/templates/ios-app/` にある。構成は `docs/architecture-ios.md` の共通の形に従う。

## 入力

| 入力 | 中身 |
| --- | --- |
| 名前 | 英小文字。リポジトリとパッケージの名前になる |
| 表示名 | ストアに出す名前 |

## 手順

立ち上げは、次の順に進める。

1. 名前と表示名を人に確かめる。`app-plan` の下書きがあれば、その名前を使う。
2. `create-app.sh` を走らせる。
3. 作ったリポジトリで `make setup` と `make verify` を通す。
4. GitHub にリポジトリを作るかを人に聞く。作る時は、人の承認を得てから `gh repo create` する。

```sh
${CLAUDE_SKILL_DIR}/scripts/create-app.sh <名前> <表示名>
```

## create-app.sh がすること

`create-app.sh` は、`~/Applications/AppStore/<名前>/` に次のことをする。置き場所は `APPS_DIR` で変えられる。

- フォルダに `docs/` のほかの中身があれば、`NG` を出して止まる。
- 名前がパッケージのモジュール（`core`・`store` など）と同じ時は、`NG` を出して止まる。
- 表示名に `"`・`\`・改行がある時も、`NG` を出して止まる。
- ひな形を写し、ファイルの中身と名前の `__App__`・`__app__`・`__DisplayName__` を置き換える。
- `docs/overview.md`・`docs/roadmap.md` が無ければ、`app-plan` のひな形を置く。
- app-plan のひな形は、app-plan の `templates/` から直に写す。app-plan が同じ claude-config に要る。
- overview の最初の 1 文を、README の説明の文に写す。
- `git init` し、最初の commit を作る。

置き換えた後の名前は、次の形になる。

| 印 | 値 | `kakeibot` の例 |
| --- | --- | --- |
| `<App>` | 名前の頭を大文字にしたもの | `Kakeibot` |
| Bundle ID | `com.yossibank.<名前>` | `com.yossibank.kakeibot` |
| App Group | `group.com.yossibank.<名前>` | `group.com.yossibank.kakeibot` |

## ひな形の中身

ひな形は、kakeibot からアプリだけの事実を外した形である。ウィジェットと通知のターゲットは入れていない。要る時に、共通の形に合わせて Xcode で足す。

| 置き場所 | 中身 |
| --- | --- |
| 直下 | CLAUDE.md、README、Makefile、Brewfile、Mintfile |
| 直下の設定 | `.swiftformat`、`.pre-commit-config.yaml` |
| `scripts/verify.sh` | 確認の名前とコマンドを受け、成否と失敗の行だけを出す。全ログは `.build/verify/` に書く |
| `scripts/simulator.sh` | 使える先頭の iPhone のシミュレーターの UDID を出す |
| `ios/` | Xcode プロジェクト、ワークスペース、テストプラン、アプリのターゲット、空のプライバシーの申告 |
| `ios/Packages/<App>Kit` | Core（`Identifier`）、Store（`AppDatabase` と最初のマイグレーション） |
| `ios/Packages/<App>App` | AppFeature（`RootView`）、DesignSystem、Features（`HomeView`） |

## 報告

人には、次のものを返す。

- 作ったリポジトリのパス
- `make verify` の結果
- GitHub に作ったか（作った時は URL）
- 公開の前に要ること（空の `AppIcon` に入れるアプリアイコンなど）
