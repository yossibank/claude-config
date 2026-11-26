# iOS アプリの名前と置き場所

> [!NOTE]
> 個人アプリの iOS 版で、フォルダとファイルの名前と、迷いやすいファイルの置き場所が分かる。
> フォルダの木は [ios-architecture](ios-architecture.md) にある。Swift のファイル全般の決まりは `dotclaude/rules/swift-core.md` にある。

## 🏷️ 名前の決まり

フォルダとファイルの名前は、次の決まりで付ける。

| 対象 | 名前の決まり |
| --- | --- |
| `Screens` の下 | 画面の名前。一覧の画面は複数形 |
| `Shared` の下 | 部品の役割の名前 |
| 機能の束 | 機能ごとにフォルダを分ける親のフォルダ。`Core/Concepts`・`Features/Screens`・`AppWidget/Widgets` |
| `Shared` の置き場所 | 機能のフォルダと同じ階層に置かない。1 段上で機能の束と並べる |
| テストのフォルダ | `Tests/` の下に、ソースと同じフォルダ分けで置く。`Shared` のテストは、`Shared/` の中を子フォルダに分けない |
| フォルダ | ファイルが 1 つだけのフォルダは作らず、近いフォルダに入れる。ターゲットの直下、`Shared` の下の役割のフォルダ、ソースにそろえたテストは例外 |
| ファイル | 中の型の名前。拡張は `<型>+<役割>.swift` |
| 入れ子の型の拡張 | `.` を抜いてつなぎ、途中の親を省かない。`Wallet.Kind` の拡張は `WalletKind+Title.swift` |
| モディファイア | DesignSystem の、画面をまたいで使うものだけ `View+<役割>.swift` にする。画面ごとのものは画面の名前で始める |
| `Store/Writes/Methods/`・`Store/Queries/Methods/` | `AppDatabase+` の後ろは、Core の型の名前のまま書く（`AppDatabase+EntryTag`） |
| fixtures | 頭に、試す型の名前を kebab-case で付ける。形は `<型>-<場合>.json` |
| テストのファイル | `dotclaude/rules/swift-test.md` の「テストの名前」に従う |

## 📏 役割と語尾の語

拡張の役割と部品の語尾は、同じ役割に同じ語を使う。アプリだけの語は、アプリの名前の文書に行を足してから使う。

### 拡張の役割の語

拡張のファイルの `+` の後ろは、次の語にそろえる。

| 語 | 足すもの | 例 |
| --- | --- | --- |
| `+Actions` | 画面の操作。複数形にする | `CategoryListView+Actions` |
| `+Input` | モデルの入れ子の `Input` の中身 | `EntryModel+Input` |
| `+Load` | モデルの読み込み | `RecurringEditModel+Load` |
| `+Message` | エラーと問題の文 | `DraftProblem+Message` |
| `+Output` | モデルの入れ子の `Output` の中身 | `EntryModel+Output` |
| `+Record` | 表の行への適合 | `Entry+Record` |
| `+Screen` | 子のモデルと画面に渡す物を作る関数 | `EntryModel+Screen` |
| `+Sheets` | 画面から開くシートの種類と振り分け。複数形にする | `EntrySheet+Sheets` |
| `+State` | モデルの入れ子の `State` の中身 | `EntryModel+State` |
| `+Text` | 値から組み立てる文 | `BudgetUsage+Text` |
| `+Title` | 選択肢と種類の表示名 | `WalletKind+Title` |

表に無い語は、そのファイルが足す物の名前に入っている語にする。`AssetsView+Trend` は、`trendContent` を足すので通る。code-design-check が確かめる。

次の語は、表に無くても使える。

- お知らせの版（`+V1_2_0`）
- import する枠組みの名前（`+CloudKit`）
- ほかのファイルと同じ名前（`AppDatabase+EntryTag`）
- 2 つ以上のファイルで使う話題の語

複数の型をまたぐ文言は、拡張にせず `<頭>Text` の名前空間の enum に置く。例は `PeriodText` である。

### 部品の語尾

型の語尾は、次の役割で使い分ける。

| 語尾 | 役割 |
| --- | --- |
| `Card` | 面を持つ、ひとまとまりの部品 |
| `Choice` | 選ぶ 1 件を表す値 |
| `Drawer` | 下から引き出す入力の板 |
| `Model` | `@Observable` の画面のモデルだけに付ける。処理の名前空間には付けない |
| `Preview` | 設定の見本を出す部品 |
| `Row` | 一覧の 1 行 |
| `Sheet` | 画面から開くシート。編集は `<対象>EditSheet` と `<対象>EditModel` の対にする |
| `Tile` | 格子の 1 マス |
| `View` | 画面の本体 |

## 📂 置き場所の決まり

迷いやすいファイルは、次の場所に置く。

| ファイル | 置き場所 |
| --- | --- |
| ウィジェットとコントロールの AppIntent | すべて `AppWidget/Intents/`。頭に、使うウィジェットの名前を付ける |
| コントロール | ウィジェットと同じく、`AppWidget/Widgets/` の下にフォルダを分ける。ファイルが 1 つでも分ける |
| 行の型の拡張 | `Store/Records/Rows/` |
| 行の型が従うプロトコル | `Store/Records/Protocols/` |

次のフォルダは、[ios-architecture](ios-architecture.md) のフォルダの木に無い。頭が同じファイルが増えた時に、役割の子フォルダとして足す。数の目安は、`dotclaude/rules/swift-core.md` の「ファイルとフォルダ」にある。

- `Store/Records/Rows/`
- `Store/Records/Protocols/`
- `Store/Writes/Methods/`
- `Store/Queries/Methods/`

DesignSystem の `Components/` の子フォルダは、種類と題材の 2 通りがある。

| フォルダ | 入れるもの |
| --- | --- |
| 種類（`Button/`・`Modal/`・`Text/` など） | 1 つの種類の部品。題材をまたいで使う部品は、ここに置く |
| 題材（`Entry/`・`Template/` など） | その題材の型を表す部品と、その型の拡張だけ |
