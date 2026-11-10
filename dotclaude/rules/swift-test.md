---
paths:
  - "**/*Tests/**/*.swift"
---

# Swift のテストの書き方

テストを読み書きする時に読み込まれる決まり。`swift-core.md` に足して、テストの名前・空行・型の分け方を決める。

## テストの名前

テストのファイルと型は、試すものに合わせて次の名前にする。

| 試すもの | 名前 | 例 |
| --- | --- | --- |
| 1 つのソースのファイル | ソースのファイル名から `+` を抜き、`Tests` を付ける | `ThemePaletteContrastTests` |
| 1 つのソースを話題で分ける | 上の名前の `Tests` の前に話題を足す | `BudgetCarryoverTests` |
| 1 つのテストの型を分ける | `<テストの型>+<話題>.swift` | `EntryModelTests+Item` |
| `Store/Writes/` の `AppDatabase+<型>` | `<型>WriteTests` | `EntryTagWriteTests` |
| `Store/Queries/` | 返す型の名前に `Tests` を付ける | `EntryHistoryTests` |
| `Store/Sync/` | `Sync<話題>Tests` | `SyncConflictTests` |
| 同じ役割の複数のファイル | 役割の名前に `Tests` を付ける | `DatabaseValueTests` |

## テスト

テストは、次の決まりで書く。

- 準備・実行・確認を空行で分ける。`let` が続いて最後の `#expect` が 1 つだけなら、空行を入れない。テストの中では、文の種類でまとめる決まりよりこちらを優先する。
- 実行と確認を繰り返すテストは、実行と確認のまとまりごとに空行で区切る。
- テストで使う型は `extension` に、テストデータの読み込みは `private extension` に分ける。
