---
paths:
  - "**/*.swift"
  - "**/*.{kt,kts}"
---

# 設計の決まり

Swift と Kotlin のコードを読み書きする時に読み込まれる決まり。不正な状態と写しを作らない形を決め、検査で止める数を示す。

## 状態の持ち方

画面のモデルと状態のクラスは、不正な状態を作れない形で値を持つ。

| 対象 | 決まり |
| --- | --- |
| 一緒に動く値 | 必ず一緒に書き換える値は、1 つの型にまとめる。Swift は `struct`、Kotlin は `data class` にする |
| 両立しない状態 | Bool や Optional を並べず、1 つの値で持つ。Swift は `enum`、Kotlin は `sealed interface` にする |
| 表示中のもの | シート・確認・メニューは、開いている 1 つを表す値で持つ。種類ごとの Bool を並べない |
| 段階のある処理 | 待ち・実行中・済み・失敗は、段階を表す 1 つの値で持つ |
| 読み込んだ値 | 値と「読んだ」のフラグを組にしない。値を Optional にするか、読み込みの段階の型に入れる |
| 入力の下書き | 入力の項目は、1 つの下書きの型にまとめる。変更の有無は、読み込んだ時の値と比べて出す |
| 派生する値 | 保存せず、計算で出す。重い計算は、入力を 1 つの型にまとめ、1 か所で作り直す |
| 値を覚える | 計算の結果を覚える時は、元の入力を鍵にする。入力ごとに手で消さない |
| 今の時刻と今日 | 型の中で作らず、引数で受け取る。引数の既定値にも書かない |
| 書き換える範囲 | 外から読むだけの値は、外から書けない範囲にする。Swift は `private(set)`、Kotlin は `private set` にする |

## モデルの形

画面のモデルは、次のまとまりだけを持つ。使わないまとまりは書かない。Swift は `let`、Kotlin は `val` で持つ。

| まとまり | 型 | 持つもの |
| --- | --- | --- |
| `state` | `@Observable` のクラス `State` | 人の操作で変わる値と、表示中のもの |
| `input` | `@Observable` のクラス `Input` | DB から来る値と、最初に渡されて変わらない値。DB から読んで人が選んで保存する値も、ここに置く |
| `output` | クラス `Output` | `input` と `state` から計算で出す値 |
| `dependencies` | 構造体 `Dependencies` | DB と時計 |

まとまりの中は、次の決まりで書く。

| 対象 | 決まり |
| --- | --- |
| 連動する値 | `didSet` を書かない。`private(set)` にして、`State` の関数で一緒に書き換える |
| 派生する値 | `Output` の計算プロパティで出す。重い計算だけ、読んだ値が変わるまで覚える部品で包む |
| `Output` の中 | DB・`dependencies`・`async` を使わない。操作と読み込みは、モデルの関数に置く |
| 入力の下書き | `State` の値から、`Output` が下書きの型を作る。変更の有無は、`input` に置いた読み込み時の下書きと比べる |
| 今の時刻 | `dependencies` の時計から受け取る。モデルのファイルで `Date()` を書かない |
| View | `model.state.x`・`model.input.x`・`model.output.x` の形で読む。モデルに転送のプロパティを足さない |
| `input` に書く | モデルの関数だけが書く。View やほかの型からは書かず、`Bindable` でも包まない |
| 共通の型 | まとまりの中身が共通の型で足りる時は、入れ子の型を作らずに、それを使ってよい |
| 子のモデル | 子のモデルや画面に渡す物は、モデルの関数が作る。View は `dependencies` を読まない |
| 外に見せる範囲 | Swift の `Input` の `public` な `var` は、`public internal(set)` にする。`Dependencies` の中身は `public` にしない |
| DB と時計 | `@Observable` のクラスは、名前によらず直接持たない。`dependencies` にまとめ、まとまりの形にする |
| 共通のプロトコル | 転送のプロパティを求めない。`state` と `input` を求め、そこから読む |
| `Output` と時刻 | 日付で足りる時は、`state` の今日を使う。時刻が要る時は、モデルの関数が引数で渡す |
| 見せない持ち物 | 進行中の処理や頼み直しの控えは、見張らない値にする。画面から触れない所に置く |

Kotlin は、同じまとまりを次の形で書く。

| まとまり | Kotlin の形 |
| --- | --- |
| `state` | 入れ子の `class State`。値は `mutableStateOf` の `var` で持つ |
| `input` | 入れ子の `class Input`。値は `internal set` の `mutableStateOf` で持ち、集まりは書き換えられない型にする |
| `output` | 入れ子の `class Output`。`derivedStateOf` はここに置き、計算は拡張に分けてよい |
| `dependencies` | `private val` で持ち、型は `private class Dependencies` にする。モデルの関数だけが使う |

## 画面の形

画面は、意味のある状態を持たない。Swift の `View` と Kotlin の Composable が持てる物は、次のとおりである。

| 持ち物 | Swift | Kotlin |
| --- | --- | --- |
| モデル | `@State` の、型の名前が `Model` で終わる値。子のモデルも同じ | `remember { XModel(...) }` |
| 見た目の値 | `@State private var layout = Layout()`。型は、View の入れ子の `struct Layout` にする | `remember { Layout() }`。型は、画面のファイルの `class Layout` にする |
| 仕組みの持ち物 | `@FocusState`・`@Namespace`・`@GestureState` | `rememberScrollState`・`rememberLazyListState`・`FocusRequester` など |
| 外から受け取る物 | `@Environment`・`@Bindable var model`・`let model` | 引数と `CompositionLocal` |

持ち物は、次の決まりで置く。

| 対象 | 決まり |
| --- | --- |
| 意味のある状態 | モデルの `state` に置く。出しているシート・確認中か・編集中か・選んでいる物・入力中の文字である |
| `Layout` の中 | 寸法・位置・スクロールの型だけを置く。Bool・文字列・整数・ID・ドメインの型は置かない |
| Swift の寸法の型 | `CGFloat`・`CGSize`・`CGRect`・`CGPoint`・`CGVector`・`EdgeInsets`・`ScrollPosition`・`ScrollGeometry`。動きの進みは、`Double` と `Angle` で持つ |
| Kotlin の寸法の型 | `Dp`・`DpSize`・`DpOffset`・`Float`・`Offset`・`IntOffset`・`Size`・`IntSize`・`Rect`・`IntRect`・`PaddingValues` |
| 型の包み | 寸法の型の Optional・配列・集合と、値が寸法の型の辞書は置ける。辞書の鍵は問わない |
| Kotlin の状態 | Composable の関数で、`mutableStateOf` の仲間を直接作らない。作るのは、モデルと状態のクラスと `Layout` の中だけにする |
| DesignSystem の部品 | モデルを持てないので、この決まりの外に置く。部品の中だけで閉じる状態は、部品が持ってよい |
| プレビュー | `@Previewable` の `@State` と `@Preview` の関数は、この決まりの外に置く |

新しい画面は、`code-screen` のスキルのひな形から始める。モデル・画面・テストが、この節の形で置かれる。

画面は、非同期の処理を自分で始めない。入口と出口は、次の決まりで書く。

| 対象 | 決まり |
| --- | --- |
| 入口 | 画面は、モデルの口から処理を始める。Swift は `Task` を画面に書かない。Kotlin は、画面でスコープを作らず、スコープから `launch` しない |
| 出口 | モデルは、結果を `state` に置く。画面は、関数の戻り値を待たずに、`state` の変化を 1 か所で受ける |
| 画面の寿命の読み込み | Swift の `.task` と Kotlin の `LaunchedEffect` は書いてよい。中では、モデルの関数を呼ぶだけにする |
| 画面だけの非同期 | 指の動きを追うような処理は、View でない型に置く。始めた処理は値で持ち、取り消せるようにする。Kotlin は、`LaunchedEffect` と `pointerInput` の中に書く |
| DesignSystem の部品の非同期 | 呼ぶモデルが無いので、この決まりの外に置く |

## 重複

同じ形のコードは、2 つ目を書く前に括る。

| 場面 | すること |
| --- | --- |
| 書く前 | 似た画面・型・関数を、名前と役割で探す。アプリに共通の部品の一覧があれば、先に読む |
| 2 つ目を書く | 写さずに、共通の部品・関数・プロトコルの既定の実装に括り、両方から使う |
| 一覧を回す | 表・設定のキー・画面の並びを複数の所で使う時は、1 か所で定義して回す |
| 定型の並び | 画面の外枠・確認・見張りのような決まった並びは、1 つの部品か関数にして呼ぶ |
| 括った後 | `Shared` に置いたプロトコルは、共通の部品の一覧に使いどころと一緒に足す |
| 別の OS へ写す | 写す前に、元の側の重複を括る。括った形のまま写す |

共通の部品の一覧は、アプリの `docs/architecture-parts.md` である。形は、claude-config の `docs/app/ios-architecture.md` にある。

## API の形

同じ役割の関数と型は、同じ形にそろえる。

| 対象 | 決まり |
| --- | --- |
| 引数 | 同じ役割の関数は、引数の名前・順・必須かどうかをそろえる |
| 戻り値 | 同じ役割の関数は、同じ型を返す。取り消せる削除は、どれも取り消しに使う値を返す |
| 対象が無い時 | 空の値・無い値・エラーを混ぜず、同じ役割の関数で 1 つに決める |
| エラーの型 | 名前を `<対象><役割>Error` の形にそろえる。見つからないなどの共通の理由は、共通の型で表す |
| 型付きの値 | ID・日付・色は、文字列や数に直さずに型のまま渡す。直すのは、保存と通信の直前だけにする |
| 2 つの場合 | 意味を読み取れない Bool の引数にせず、場合を表す型にする |
| 検証 | 入力の検証は、下書きの型が問題の一覧を返す形にそろえる |

## 置き場所

処理は、役割で置く層を決める。

| 対象 | 決まり |
| --- | --- |
| 計算 | 集計・並べ替え・検証は、画面に書かずに、画面を持たない層とモデルに置く |
| 文字列の組み立て | 金額・日付・文言の整形は、1 か所の型か関数に集める。画面の中で組み立てない |
| 数値 | 余白・角の丸み・時間・大きさで 2 か所以上に出る値は、DesignSystem の定数にする |
| 層の境目 | 下の層は上の層の言葉を持たない。画面の文言と並べ方を、保存の層に置かない |
| ファイルの大きさ | 1 つのファイルは 400 行までにする。超える前に、役割ごとのファイルに分ける |
| ファイルと型 | private でない型は、ファイルの名前で始める。名前の決まりは、言語ごとの rules にある |

## 守らせる仕組み

検査は `hooks/code-design-check.py` が行う。`.swift` と `.kt` を Edit・Write した後に走る。アプリの `make verify` は、追跡している全部のファイルに同じ検査をかける。

| 決まり | 見ること | 上限 |
| --- | --- | --- |
| ファイルの大きさ | 1 つのファイルの行の数。テストも見る | 400 行 |
| ファイルと型 | Swift のファイルの名前と、中の型・拡張する型の名前 | |
| ファイルと型 | private でない型の名前が、ファイルの名前で始まるか。Kotlin はファイルの名前の語で見る | |
| フォルダ | Swift の 1 つのフォルダで、頭が同じファイルの数。通し番号のファイルは除く | 20 本 |
| 一緒に動く値 | Swift の `@Observable` のクラスの、保存プロパティの `var` の数 | 12 個 |
| 一緒に動く値 | Kotlin の 1 つのファイルの、`mutableStateOf` の `var` の数 | 12 個 |
| 両立しない状態 | Swift の `@Observable` のクラスの、Bool の保存プロパティの数 | 3 個 |
| 派生する値 | Swift の `@Observable` のクラスの、`didSet` と `willSet` の数 | 2 個 |
| モデルの形 | `state`・`input`・`output` の `let` を持つクラスの、直下の保存プロパティの `var` の数 | 0 個 |
| モデルの形 | まとまりを `var` で持っていないか。Swift は、まとまりの型の `var` が 2 つ以上あるクラスを見る | |
| モデルの形 | `@Observable` のクラスが、DB か時計の型の値を直接持っていないか。Kotlin は、状態を持つクラスのファイルを見る | |
| モデルの形 | まとまりのモデルと、入れ子の `State`・`Input` の、`didSet` と `willSet` の数 | 0 個 |
| モデルの形 | 入れ子の `State` の `var` と Bool の数。`Input` は数えない | 12 個・3 個 |
| モデルの形 | `Output` のクラスと拡張の中に、`await`・`async`・`AppDatabase`・`dependencies` が無いか | |
| モデルの形 | `Output` のクラスと拡張の中に、`Date()`・`Date.now` が無いか。Kotlin は `Instant.now()` などを見る | |
| モデルの形 | `dependencies.` を使うファイルに、`Date()`・`Date.now` が無いか | |
| モデルの形 | `self` 以外から `.input.` に書いていないか。代入・添字・`append`・`insert`・`remove`・`toggle` と、`input` を包む `Bindable` を見る | |
| モデルの形 | Swift の `Input` で終わる クラスの `public var` に、`(set)` があるか | |
| モデルの形 | Swift の `Dependencies` で終わる構造体に、`public` の値が無いか | |
| モデルの形 | Kotlin のまとまりの `val` を持つクラスの、直下の `mutableStateOf` の数 | 0 個 |
| モデルの形 | Kotlin の入れ子の `State` の、`mutableStateOf` の `var` と Boolean の数 | 12 個・3 個 |
| モデルの形 | Kotlin の `Output` とその拡張に、`suspend`・DB・`dependencies` が無いか | |
| モデルの形 | Kotlin の `dependencies.` を使うファイルに、`Instant.now()` などが無いか | |
| モデルの形 | Kotlin の `this` 以外から `.input.` に書いていないか。代入と、`add`・`remove`・`put`・`clear` の呼び出しを見る | |
| モデルの形 | Kotlin の `Input` の `var` が、`internal set` か `private set` か。引数の `var` は `internal var` か | |
| モデルの形 | Kotlin の `Input` に、書き換えられる集まりが無いか | |
| モデルの形 | Kotlin のモデルのクラスの `dependencies` が `private` か。まとまりか状態を持つクラスだけを見る | |
| モデルの形 | Swift の `self` 以外の `.dependencies` の読み出しが無いか | |
| モデルの形 | `.output.state`・`.output.input` の読み出しが無いか | |
| 画面の形 | Swift の `@State` の型が、Optional と配列は中の型が、`Model` で終わる型か `Layout` か。`@Previewable` の行は除く | |
| 画面の形 | Swift の `struct Layout` の保存プロパティが、寸法の型か。型を読み取れない値も止める | |
| 画面の形 | Kotlin の `@Composable` のあるファイルの関数が、`mutableStateOf` の仲間を作っていないか。`@Preview` の関数は除く | |
| 画面の形 | Kotlin の `class Layout` の本体のプロパティが、寸法の型か。型を読み取れない値も止め、コンストラクターの引数は見ない | |
| 画面の形 | Swift の画面のファイルに、`Task {`・`Task(`・`Task.detached` が無いか | |
| 画面の形 | Kotlin の `@Composable` のあるファイルに、`rememberCoroutineScope`・`CoroutineScope(`・`MainScope(`・`GlobalScope` が無いか | |
| 画面の形 | Kotlin の `@Composable` のあるファイルの関数に、スコープから始める `.launch {`・`.async {` が無いか | |
| 今の時刻と今日 | `Date()`・`Instant.now()` などを、引数やプロパティの既定値に書いていないか | |
| 2 つ目を書く | 名前だけが違う同じ形の行が、別のファイルと続けて重なる数。テストと通し番号のファイルは除く | 19 行 |
| 括った後 | Swift の `Shared` のプロトコルが、共通の部品の一覧にあるか。一覧がある時だけ見る | |

検査の範囲は、次のとおりである。ここに無い決まりは、仕組みでは見ていない。

- テストのファイルは、大きさだけを見る。
- リポジトリの `.claude/` の下は、道具のためのコードなので見ない。
- `input` への書き込みと `dependencies` の読み出しは、それを持つモデルと同じモジュールだけを見る。
- 別のモジュールの画面からは、コンパイルが止める。モジュールを見分けられないファイルは見る。
- Swift のモジュールは、`Sources/<ターゲット>` のフォルダで見分ける。
- Kotlin のモジュールは、`build.gradle.kts` か `build.gradle` のあるフォルダで見分ける。
- 画面の形は、`DesignSystem`（Kotlin は `designsystem`）のフォルダの下を見ない。
- 画面の形は、`@State` の行と関数の中の行を 1 行ずつ見る。型は、書かれた型か初めの値の頭で読む。
- `@State` の型が同じファイルにあり、寸法の型の値だけを持つ時は、`Layout` にまとめるよう知らせる。
- 画面のファイルは、View か ViewModifier を宣言するファイルである。
- 同じモジュールの View を拡張するファイルと、`extension View` のファイルも画面と見る。
- モデルを持たずに View を宣言するモジュールでは、`@Observable` のクラスとその拡張のファイルも画面と見る。
- モジュールを見分けられない時は、同じフォルダの下の View を拡張するファイルまでを画面と見る。
- 画面のファイルでも、`Task<…>?` の保存プロパティに入れて `cancel()` で取り消す `Task` は通す。
- その保存プロパティは、同じファイルの View の外で宣言した物だけを見る。`@State` は当たらない。
- Kotlin のコルーチンは、`@Preview` の関数を除く。`.launch {` と `.async {` は、クラスの中を見ない。
- `LaunchedEffect` と、その中の受け手の無い `launch {`、波かっこの続かない `launch(` は通す。
- 同じ形は名前を伏せて比べるので、名前を変えただけの写しも当たる。
- 型の保存プロパティ・init の引数の並び・`self.x = x` だけの行は、データの宣言なので数えない。
- 注釈の行は、複数行の引数も含め、データの宣言として数えない。
- interface・protocol・abstract の本体の無い関数の宣言も、同じく数えない。

今ある外れは、基準線に書いて見送れる。基準線は、アプリの `.claude/code-design-baseline.txt` である。

| 場面 | 検査がすること |
| --- | --- |
| 外れが基準線にある | 通す |
| 外れが基準線に無い、または数が増えた | NG にする |
| 基準線の外れが直った | `make verify` で NG にする。その行を消す |
| 基準線を作り直す | `code-design-check.py --write-baseline` に直したファイルを渡す。渡したファイルの行だけを書き直し、無いファイルの行は消す |
