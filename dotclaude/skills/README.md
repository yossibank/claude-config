# skills

スキルを、1 つずつフォルダで置く。フォルダは `~/.claude/skills/` に 1 つずつリンクされ、この README は入らない。

## 🧰 スキル

名前の頭が分類を表し、名前の順に並べると分類ごとにまとまる。分類は [接頭語の表](../../docs/config/development.md#接頭語の表)、使う順と一覧は [skills.md](../../docs/usage/skills.md) にある。

## 📂 フォルダの中

スキルのフォルダは、次の形にそろえる。

| 場所 | 置くもの | 決まり |
| --- | --- | --- |
| `SKILL.md` | 手順 | [docs-claude.md](../rules/docs-claude.md) |
| `scripts/` | そのスキルだけが呼ぶスクリプト | [development.md](../../docs/config/development.md#-名前の付け方) |
| `templates/<単位>/` | ひな形 | [layout.md](../../docs/config/layout.md#-フォルダの分け方) |

## 🪜 足し方

足す時の名前と手順は [development.md](../../docs/config/development.md#-足し方)、テストの置き方は [testing.md](../../docs/config/testing.md#-テスト) にある。
