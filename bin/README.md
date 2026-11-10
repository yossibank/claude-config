# bin

人・フック・複数のスキルが直接呼ぶスクリプトの入口を置く。入口が読む中身は [lib/](../lib/) に置き、置き方の決まりは [layout.md](../docs/config/layout.md) にある。

## 📜 スクリプト

名前の頭が分類を表し、名前の順に並べると分類ごとにまとまる。分類は [接頭語の表](../docs/config/development.md#接頭語の表) にある。

| 名前の頭 | まとまり | 一覧のある文書 |
| --- | --- | --- |
| `config-` | claude-config を入れる、検査する | [components.md](../docs/usage/components.md#-スクリプト) |
| `docs-` | 文書の節を読む、技術のアイコンを作る | [components.md](../docs/usage/components.md#-スクリプト) |

## 🪜 足し方

足す時の名前と手順は [development.md](../docs/config/development.md#-足し方)、テストの置き方は [testing.md](../docs/config/testing.md#-テスト) にある。
