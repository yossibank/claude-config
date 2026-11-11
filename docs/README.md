# docs

人と Claude が読む文書を置く。文書ごとの読む時と中身は、[README.md](../README.md#-文書) の表にある。

## 📂 フォルダ

文書は、読む時でフォルダを分ける。

| フォルダ | 置くもの | 読む時 |
| --- | --- | --- |
| [app/](app/) | アプリの共通の構成。アプリのリポジトリから名前で指される | アプリを作る時 |
| [config/](config/) | claude-config を直す時の決まり | claude-config を直す時 |
| [images/](images/) | 文書の画像 | |
| [usage/](usage/) | claude-config の部品と、入れ方 | claude-config を使う時 |

## 🗓️ 読む順

`usage/` と `config/` の文書は、場面ごとに次の順に読む。

| 場面 | 読む順 |
| --- | --- |
| 使う時 | [setup.md](usage/setup.md) → [components.md](usage/components.md) → [skills.md](usage/skills.md) |
| 直す時 | [development.md](config/development.md) → [layout.md](config/layout.md) → [testing.md](config/testing.md) → [improvements.md](config/improvements.md) |
