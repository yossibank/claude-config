# iOS アプリの名前と置き場所

> [!NOTE]
> 個人アプリの iOS 版で、フォルダとファイルの名前と、迷いやすいファイルの置き場所が分かる。
> フォルダの木は [architecture-ios](architecture-ios.md) にある。Swift のファイル全般の決まりは `rules/swift-core.md` にある。

## 🏷️ 名前の決まり

フォルダとファイルの名前は、次の決まりで付ける。

| 対象 | 名前の決まり |
| --- | --- |
| `Screens` の下 | 画面の名前。一覧の画面は複数形 |
| `Shared` の下 | 部品の役割の名前 |
| `Shared` の置き場所 | 機能のフォルダと同じ階層に置かない。1 段上で機能の束と並べる |
| 機能の束 | `Core/Concepts`・`Features/Screens`・`AppWidget/Widgets` |
| テストのフォルダ | ソースと同じフォルダに置く。`Shared` のテストは、`Shared/` の中を子フォルダに分けない |
| フォルダ | ファイルが 1 つだけのフォルダは作らず、近いフォルダに入れる。ターゲットの直下、`Shared` の下の役割のフォルダ、ソースにそろえたテストは例外 |
| ファイル | 中の型の名前。拡張は `<型>+<役割>.swift` |
| モディファイア | DesignSystem の、画面をまたいで使うものだけ `View+<役割>.swift` にする。画面ごとのものは画面の名前で始める |
| `Store/Writes/Methods/`・`Store/Queries/Methods/` | `AppDatabase+` の後ろは、Core の型の名前のまま書く（`AppDatabase+EntryTag`） |
| fixtures | 頭に、試す型の名前を kebab-case で付ける。形は `<型>-<場合>.json` |
| テストのファイル | `rules/swift-test.md` の「テストの名前」に従う |

## 📂 置き場所の決まり

迷いやすいファイルは、次の場所に置く。

| ファイル | 置き場所 |
| --- | --- |
| ウィジェットとコントロールの AppIntent | すべて `AppWidget/Intents/`。頭に、使うウィジェットの名前を付ける |
| コントロール | ウィジェットと同じく、`AppWidget/Widgets/` の下にフォルダを分ける。ファイルが 1 つでも分ける |
| 行の型の拡張 | `Store/Records/Rows/` |
| 行の型が従うプロトコル | `Store/Records/Protocols/` |

DesignSystem の `Components/` の子フォルダは、種類と題材の 2 通りがある。

| フォルダ | 入れるもの |
| --- | --- |
| 種類（`Button/`・`Modal/`・`Text/` など） | 1 つの種類の部品。題材をまたいで使う部品は、ここに置く |
| 題材（`Entry/`・`Template/` など） | その題材の型を表す部品と、その型の拡張だけ |
