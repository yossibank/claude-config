---
paths:
  - "**/src/test/**/*.kt"
  - "**/src/*Test/**/*.kt"
---

# Kotlin のテストの書き方

テストを読み書きする時に読み込まれる決まり。`kotlin-core.md` に足して、テストの名前・空行・型の分け方を決める。

## テストの名前

テストのファイルとクラスは、試すものに合わせて次の名前にする。

| 試すもの | 名前 | 例 |
| --- | --- | --- |
| 1 つのソースのファイル | ソースのファイル名に `Test` を付ける | `ThemePaletteContrastTest` |
| 1 つのソースを話題で分ける | 上の名前の `Test` の前に話題を足す | `BudgetCarryoverTest` |
| `store/writes/` の書き込み | `<型>WriteTest` | `EntryTagWriteTest` |
| `store/queries/` | 返す型の名前に `Test` を付ける | `EntryHistoryTest` |
| `store/sync/` | `Sync<話題>Test` | `SyncConflictTest` |
| 同じ役割の複数のファイル | 役割の名前に `Test` を付ける | `DatabaseValueTest` |

iOS に同じテストがある時は、iOS の名前の `Tests` を `Test` に変えた名前にする。テストの関数は、iOS のテストと同じ名前にする。

## テスト

テストは、次の決まりで書く。

- 準備・実行・確認を空行で分ける。`val` が続いて最後の確認が 1 つだけなら、空行を入れない。
- テストの中では、文の種類でまとめる決まりより上の分け方を優先する。
- 実行と確認を繰り返すテストは、実行と確認のまとまりごとに空行で区切る。
- テストで使う型と、テストデータの読み込みは、テストのクラスの後に `private` で置く。
- 複数のテストのファイルで使う道具は、`support` のフォルダに置く。
- 中断する関数を呼ぶテストは、`runTest` の中に書く。
