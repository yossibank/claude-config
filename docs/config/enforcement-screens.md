# 画面と置き場所の守り方

> [!NOTE]
> [code-design.md](../../dotclaude/rules/code-design.md) の画面の形から置き場所までの決まりを、今は何で守っているかが分かる。
> 守り方の強さとセルの書き方は、[enforcement.md](enforcement.md) にある。

## 🗺️ 決まりと守り方

行は、code-design.md の節と表の順に並べる。数の上限・検査の範囲・基準線は、code-design.md の「守らせる仕組み」にある。

### 画面の形

画面の持ち物の決まりは、次のように守る。検査の関数は、`view.py` にある。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| モデル・流れ・指の動きを追う型 | 検査 `check_swift_view`。`@State` の型の名前の終わりだけを見る | レビューのみ。`remember` の中身は見ない |
| 見た目の値 | 検査 `check_swift_view`。寸法の型の `@State` は、`Layout` にまとめるよう知らせる | 検査 `check_kotlin_view`。寸法の型の `mutableStateOf` は、`Layout` にまとめるよう知らせる |
| 意味のある状態 | 検査 `check_swift_view`。`@State` の行だけを見る | 検査 `check_kotlin_view`。`mutableStateOf` の仲間だけを見る |
| `Layout` の中・動きの段階の型 | 検査 `check_swift_layout`。型を読み取れない値も止め、段階の型は名前と同じファイルの宣言を見る | 検査 `check_kotlin_layout`。引数と getter は見ない |
| Swift の寸法の型 | 検査 `check_swift_layout`。`SWIFT_METRICS` と比べる | Swift の決まりである |
| SwiftUI の寸法の型 | 検査 `check_swift_layout`。`SWIFT_METRICS` と比べる | Swift の決まりである |
| Kotlin の dp の型 | Kotlin の決まりである | 検査 `check_kotlin_layout`。`KOTLIN_METRICS` と比べる |
| Kotlin の px の型 | Kotlin の決まりである | 検査 `check_kotlin_layout`。`KOTLIN_METRICS` と比べる |
| 型の包み | 検査 `check_swift_layout`。包みの中の型を見る | 検査 `check_kotlin_layout`。見方は Swift と同じである |
| Kotlin の状態 | Kotlin の決まりである | 検査 `check_kotlin_view`。`@Composable` のあるファイルの関数を見る |

次の決まりは、許す決まりなので、守るものが無い。

- 仕組みの持ち物
- 外から受け取る物
- DesignSystem の部品
- プレビュー

DesignSystem のフォルダは、`is_part_library` が検査から外す。`@Previewable` の行と `@Preview` の関数も外す。

新しい画面は、`code-screen` のひな形から始める。ひな形が検査を通ることは、`tests/skills/code-screen.sh` が確かめる。Swift のひな形は、仮のパッケージでビルドとテストも通す。

非同期の処理の決まりは、次のように守る。検査の関数は、`effect.py` にある。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 入口 | 検査 `check_swift_effect`。画面のファイルと画面のモジュールの `Task` の始まりを見て、モデルと同じモジュールの View でない型は見ない | 検査 `check_kotlin_effect`。スコープを作る行と、関数の中の `.launch {`・`.async {` を見る |
| 出口 | レビューのみ | レビューのみ |
| 画面の寿命の読み込み | レビューのみ。`.task` の中身は見ない | レビューのみ。`LaunchedEffect` の中身は見ない |
| 画面だけの非同期 | 検査 `check_swift_effect`。`Task<…>?` の保存プロパティへの代入と `cancel()` の有無を見る | 検査 `check_kotlin_effect`。許す形は無く、`LaunchedEffect` か `pointerInput` の中に書く |
| DesignSystem の部品の非同期 | 許す決まりなので、守るものが無い | 許す決まりなので、守るものが無い |

### 画面の部品

実行中の印と、表示中のもの・読んだ印の Bool は、`flags.py` の検査が名前で止める。`State` で画面が書ける値が `ScreenEditable` の型だけかは、`editable.py` の検査が型で止める。ほかの部品は、レビューのみで守る。

### 重複

同じ形の検査は、Swift と Kotlin を別々に比べる。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 書く前 | 文だけ。探したかどうかは、差分に出ない | 文だけ。探したかどうかは、差分に出ない |
| 2 つ目を書く | 検査 `Clones.check`。名前を伏せて、20 行以上の重なりだけを見る | 検査 `Clones.check`。見る範囲は Swift と同じである |
| 一覧を回す | レビューのみ | レビューのみ |
| 定型の並び | レビューのみ。20 行以上の写しは、`Clones.check` が当てる | レビューのみ。20 行以上の写しは、`Clones.check` が当てる |
| 括った後 | 検査 `check_parts`。共通の部品の一覧がある時だけ見る | レビューのみ |
| 別の OS へ写す | レビューのみ | レビューのみ |

### API の形

次の決まりは、Swift も Kotlin もレビューのみで守る。

- 引数
- 戻り値
- 対象が無い時
- エラーの型
- 型付きの値
- 2 つの場合
- 検証

### 置き場所

層の境目の Swift は、ひな形の `Package.swift` の依存の向きで確かめた。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 計算 | レビューのみ | レビューのみ |
| 文字列の組み立て | レビューのみ | レビューのみ |
| 数値 | レビューのみ | レビューのみ |
| 層の境目 | 型。下のターゲットは上を import できず、文言を下の層に書くことだけはレビューで見る | 未確認 |
| ファイルの大きさ | 検査 `check_length`。テストのファイルも見る | 検査 `check_length`。テストのファイルも見る |
| ファイルと型 | 検査 `check_swift_name`・`check_swift_types`。語は `names.py` の検査が見る | 検査 `check_kotlin_types`。ファイルと同じ名前の型があるかは見ない |
