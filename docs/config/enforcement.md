# 設計の決まりの守り方

> [!NOTE]
> [code-design.md](../../dotclaude/rules/code-design.md) の決まりの 1 つ 1 つを、今は何で守っているかが分かる。
> 型で守れるようになった検査を消す時に、ここで確かめる。

## 📏 守り方の強さ

守り方は、強い順に次のように分ける。対応の表のセルは、いちばん強い守り方の名前で始める。

| 順 | 守り方 | 止まる時 | セルの書き方 |
| --- | --- | --- | --- |
| 1 | 型とモジュールの境界 | コンパイル | 型 |
| 2 | テストとスナップショット | アプリのテスト | テスト |
| 3 | 正規表現の検査 | `.swift` と `.kt` の Edit・Write の後と、アプリの `make verify` | 検査 |
| 4 | レビュー | PR を作る前の `reviewer` | レビューのみ |
| 5 | 決まりの文だけ | 止まらない | 文だけ |

検査の関数は、`lib/hooks/code_design_check/` にある。入口は `dotclaude/hooks/code-design-check.py` である。

`tests/hooks/code-design-check.sh` は、検査そのものを確かめる。アプリのコードは確かめない。

## 🗺️ 決まりと守り方

行は、code-design.md の節と表の順に並べる。数の上限・検査の範囲・基準線は、code-design.md の「守らせる仕組み」にある。

### 状態の持ち方

数を見る検査は、まとめ方の良し悪しまでは見ない。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 一緒に動く値 | 検査 `check_swift_state`。`@Observable` のクラスの `var` の数だけを見る | 検査 `check_kotlin_state`・`check_kotlin_parts`。`mutableStateOf` の `var` の数だけを見る |
| 両立しない状態 | 検査 `check_swift_state`。Bool の数だけを見る | 検査 `check_kotlin_parts`。まとまりのモデルの `State` の Boolean だけを見る |
| 表示中のもの | レビューのみ | レビューのみ |
| 段階のある処理 | レビューのみ | レビューのみ |
| 読み込んだ値 | レビューのみ | レビューのみ |
| 入力の下書き | レビューのみ | レビューのみ |
| 派生する値 | 検査 `check_swift_state`。`didSet` と `willSet` の数だけを見る | レビューのみ |
| 値を覚える | レビューのみ | レビューのみ |
| 今の時刻と今日 | 検査 `check_now`。既定値の値と、今の時刻を作る関数を見て、名前を付けた関数と時計の既定値は見ない | 検査 `check_now`。値は `Instant`・`LocalDate`・`LocalDateTime` だけを見て、関数は Swift と同じに見る |
| 書き換える範囲 | レビューのみ。`private(set)` と書いた値は、コンパイルが守る | レビューのみ。`private set` と書いた値は、コンパイルが守る |

### モデルの形

モデルが画面と同じモジュールにある時は、次のように守る。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| まとまりだけを持つ | 検査 `check_swift_state`。直下の `var` だけを見て、余分な `let` は見ない | 検査 `check_kotlin_state`。直下の `mutableStateOf` だけを見る |
| まとまりの型と持つもの | レビューのみ | レビューのみ |
| `let`・`val` で持つ | 検査 `check_swift_state`。まとまりの型の `var` が 1 つだけのクラスは、モデルと見ない | 検査 `check_kotlin_state`。`State(`・`Input(`・`Output(` で作る `var` を見る |
| 連動する値 | 検査 `check_swift_state`。モデルと `State`・`Input` の `didSet` を 0 個にする | レビューのみ |
| 派生する値 | レビューのみ | レビューのみ |
| `Output` の中 | 検査 `check_swift_output` | 検査 `check_kotlin_output` |
| 入力の下書き | レビューのみ | レビューのみ |
| 今の時刻 | 検査 `check_swift_clock`。`dependencies.` を使うファイルだけを見る | 検査 `check_kotlin_clock`。`dependencies.` を使うファイルだけを見る |
| View | 検査 `check_passage`。`.output.state` と `.output.input` だけを見て、転送のプロパティは見ない | 検査 `check_passage`。見る範囲は Swift と同じである |
| `input` に書く | 検査 `check_swift_input` | 検査 `check_kotlin_input` |
| 共通の型 | 許す決まりなので、守るものが無い | 許す決まりなので、守るものが無い |
| 子のモデル | 検査 `check_swift_dependencies`。`self` 以外の `.dependencies` の読み出しを見る | 型。`check_kotlin_shape` が `private val` を求めるので、外から読むとコンパイルで止まる |
| 外に見せる範囲 | 検査 `check_swift_shape` | Kotlin の形の表にある |
| DB と時計 | 検査 `check_swift_shape`。型の名前が `Database` か `Clock` で終わる値だけを見る | 検査 `check_kotlin_shape`。見る型は Swift と同じである |
| 共通のプロトコル | レビューのみ | レビューのみ |
| `Output` と時刻 | 検査 `check_swift_output`。`Output` の中の `Date()` を見る | 検査 `check_kotlin_output`。`Output` の中の `Instant.now()` などを見る |
| 見せない持ち物 | レビューのみ | レビューのみ |

Kotlin の形の表は、次のように守る。

| まとまり | 守り方 |
| --- | --- |
| `state` | 検査 `check_kotlin_state`・`check_kotlin_parts`。直下の `mutableStateOf` と、`State` の中の数を見る |
| `input` | 検査 `check_kotlin_shape`。`internal set` か `private set` の有無と、書き換えられる集まりを見る |
| `output` | レビューのみ。`derivedStateOf` の置き場所は見ない |
| `dependencies` | 検査 `check_kotlin_shape`。`private` の有無を見る |

### モデルを別のモジュールに置いた時

kakeibot で、画面のモジュールに違反を書いてコンパイルした。iOS は `FeatureModels`、Android は `:featuremodels` に分けたブランチで試した。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| まとまりだけを持つ | 型。画面の側の拡張は、保存プロパティを足せない | 未確認 |
| まとまりの型と持つもの | レビューのみ。画面が `state` に書くのは通る | レビューのみ。画面が `state` に書くのは通る |
| `let`・`val` で持つ | 型。まとまりを入れ替えると止まり、画面で `State` を作るのも止まる | 型。まとまりを入れ替えると止まり、画面で `Input()` を作るのは通る |
| 連動する値 | 未確認 | 未確認 |
| 派生する値 | 未確認 | 未確認 |
| `Output` の中 | 検査。画面の側の拡張に DB と `async` を足しても通る | 検査。画面の側の拡張に DB と `suspend` を足しても通る |
| 入力の下書き | 未確認 | 未確認 |
| 今の時刻 | 検査。画面の側の拡張に `Date()` を書いても通る | 検査。画面の側の拡張に `Instant.now()` を書いても通る |
| View | 型。output 越しに読むと止まり、画面の側の拡張で足す転送のプロパティは通る | 型。output 越しに読むと止まり、画面の側の拡張で足す転送のプロパティは通る |
| `input` に書く | 型。`public internal(set)` なので、代入・`append`・`Bindable` が止まる | 型。`internal set` なので代入が止まり、`List` なので `add` も止まる |
| 共通の型 | 許す決まりなので、守るものが無い | 許す決まりなので、守るものが無い |
| 子のモデル | 型。internal の `dependencies` は止まり、`public` にした入れ物は中の DB で止まる | 型。`private` なので止まる |
| 外に見せる範囲 | 検査。宣言の決まりなので、分けても変わらない | 検査。宣言の決まりなので、分けても変わらない |
| DB と時計 | 検査。宣言の決まりなので、分けても変わらない | 検査。宣言の決まりなので、分けても変わらない |
| 共通のプロトコル | レビューのみ。転送のプロパティを求めるプロトコルを画面の側に作っても通る | 未確認 |
| `Output` と時刻 | 検査。画面の側の拡張に `Date()` を書いても通る | 検査。画面の側の拡張に `Instant.now()` を書いても通る |
| 見せない持ち物 | 型。`public` を付けない値は、画面から読むと止まる | 未確認 |

型が守る 2 つの決まりは、使う側の検査を次のように切り替える。

| 場面 | 使う側の検査 |
| --- | --- |
| ファイルのモジュールに、`input` か `dependencies` を持つモデルが無い | 走らない。型が守る |
| ファイルのモジュールに、それを持つモデルがある | 走る。同じモジュールの中は、型が守らない |
| モジュールを見分けられない | 走る |

使う側の検査は、次のとおりである。モジュールの見分け方は、code-design.md の「守らせる仕組み」にある。

- `check_swift_input`
- `check_swift_dependencies`
- `check_kotlin_input`

型の守りを外す宣言は、`check_swift_shape` と `check_kotlin_shape` が止める。

> [!WARNING]
> 次のことは、確かめていない。
>
> - 「未確認」の行。画面の側に書ける違反を作れず、コンパイルしていない。
> - アプリのテストとスナップショットが守る決まり。

### 画面の形

画面の持ち物の決まりは、次のように守る。検査の関数は、`view.py` にある。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| モデル | 検査 `check_swift_view`。`@State` の型の名前の終わりだけを見る | レビューのみ。`remember` の中身は見ない |
| 見た目の値 | 検査 `check_swift_view`。寸法の型の `@State` は、`Layout` にまとめるよう知らせる | 検査 `check_kotlin_view`。寸法の型の `mutableStateOf` は、`Layout` にまとめるよう知らせる |
| 意味のある状態 | 検査 `check_swift_view`。`@State` の行だけを見る | 検査 `check_kotlin_view`。`mutableStateOf` の仲間だけを見る |
| `Layout` の中 | 検査 `check_swift_layout`。型を読み取れない値も止める | 検査 `check_kotlin_layout`。引数と getter は見ない |
| Swift の寸法の型 | 検査 `check_swift_layout`。`SWIFT_METRICS` と比べる | Swift の決まりである |
| Kotlin の寸法の型 | Kotlin の決まりである | 検査 `check_kotlin_layout`。`KOTLIN_METRICS` と比べる |
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
| ファイルと型 | 検査 `check_swift_name`・`check_swift_types` | 検査 `check_kotlin_types`。ファイルと同じ名前の型があるかは見ない |
