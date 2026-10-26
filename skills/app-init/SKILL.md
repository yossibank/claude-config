---
name: app-init
description: 新しい iOS アプリのリポジトリを、kakeibot の形のひな形から作る。app-plan で企画を書いた後や、人が新しいアプリを始める時に使う。
argument-hint: "<アプリの名前（英小文字）> <ストアの表示名>"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.sh *)
---

# アプリを立ち上げる

`templates/ios-app/` を写して、ビルドとテストが通る新しいアプリのリポジトリを作る手順。構成は `docs/architecture-ios.md` の共通の形に従う。

## 手順

立ち上げは、次の順に進める。

1. 名前と表示名を人に確かめる。`app-plan` の下書きがあれば、その名前を使う。
2. `init.sh` を走らせる。
3. 作ったリポジトリで `make setup` と `make verify` を通す。
4. GitHub にリポジトリを作るかを人に聞く。作る時は、人の承認を得てから `gh repo create` する。

```sh
${CLAUDE_SKILL_DIR}/scripts/init.sh <名前> <表示名>
```

## init.sh がすること

`init.sh` は、`~/Applications/AppStore/<名前>/` に、次のことをする。置き場所は `APPS_DIR` で変えられる。

- フォルダに `docs/` のほかの中身があれば、`NG` を出して止まる
- 名前がパッケージのモジュール（`core`・`store` など）と同じ時と、表示名に `"`・`\`・改行がある時は、`NG` を出して止まる
- ひな形を写し、ファイルの中身と名前の `__App__`・`__app__`・`__DisplayName__` を置き換える
- `docs/overview.md`・`docs/roadmap.md` が無ければ、`app-plan` のひな形を置く
- overview の最初の 1 文を、README の説明の文に写す
- `git init` し、最初の commit を作る

`<App>` は名前の頭を大文字にしたもの（`kakeibot` なら `Kakeibot`）になる。Bundle ID は `com.yossibank.<名前>`、App Group は `group.com.yossibank.<名前>` である。

## ひな形の中身

ひな形は、kakeibot からアプリだけの事実を外した形である。ウィジェットと通知のターゲットは入れていない。要る時に、共通の形に合わせて Xcode で足す。

| 置き場所 | 中身 |
| --- | --- |
| 直下 | CLAUDE.md、README、Makefile、Brewfile、Mintfile、SwiftFormat と pre-commit の設定 |
| `scripts/verify.sh` | コマンドの全ログをファイルに書き、成否と失敗の行だけを出す |
| `ios/` | Xcode プロジェクト、ワークスペース、テストプラン、アプリのターゲット |
| `ios/Packages/<App>Kit` | Core（`Identifier`）、Store（`AppDatabase` と最初のマイグレーション） |
| `ios/Packages/<App>App` | AppFeature（`RootView`）、DesignSystem、Features（`HomeView`） |

アプリアイコンは空である。公開の前に `AppIcon` を入れる。
