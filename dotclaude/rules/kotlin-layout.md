---
paths:
  - "**/*.{kt,kts}"
---

# Kotlin の並び

Kotlin を読み書きする時に読み込まれる決まり。ファイルとクラスの中の並び・宣言と文の空行・Composable の本体の順を決める。

改行と名前は `kotlin-core.md`、画面は `kotlin-compose.md` にある。決まりの頭の番号は、検査が止める文の頭に出る。番号は Swift の `swift-layout.md` とそろえ、K5 は欠番にする。

## ファイルの区画

1 つのファイルは、次の区画を上から順に並べる。使わない区画は書かない。

| 順 | 区画 | 置くもの |
| --- | --- | --- |
| 1 | package と import | |
| 2 | 公開の const | `private` でない `const val` |
| 3 | ファイルの名前の型 | ファイルの名前と同じ名前の型 |
| 4 | ほかの公開の型 | `private` でない型と `typealias` |
| 5 | 公開と internal の値・拡張・関数 | Composable と、`const` でない値を含む |
| 6 | private の型・拡張・関数 | private の Composable と、受け手のある private の値を含む |
| 7 | private の値 | 受け手の無い private の値と、private の `const val` |
| 8 | `@Preview` | `@Preview` を付けた関数 |

区画は、次の決まりで並べる。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| K1 | 区画の順 | 区画は、表の順に並べる |
| K2 | 拡張だけのファイル | 型を宣言せず、拡張だけを置くファイルは、公開・internal・private の順に並べる |
| K2 | 拡張だけのファイルの名前 | 受け手の型の名前を、点を抜いてつなぎ、話題を足す。`EntryModel.Output` の文字なら `EntryModelOutputText.kt` |

受け手が複数の型にまたがる時は、外の型の名前で始める。

```kotlin
package com.example.export

import java.time.Instant

fun Export.csv(): String = rows().joinToString("\n")

private fun Export.rows(): List<String> = items.map { header + it }

private const val header = "日付,金額"
```

## クラスの中と入れ子の型

クラス・`object`・`interface` の中は、次の区画を上から順に並べる。

| 順 | 区画 | 置くもの |
| --- | --- | --- |
| 1 | 保存プロパティと要求 | 初めの値か委譲を持つプロパティ。画面のモデルは `state`・`input`・`output`・`dependencies` の順。`interface` と `abstract` の、本体の無いプロパティと関数も、ここに置く |
| 2 | init と副コンストラクタ | `init` と `constructor` |
| 3 | 入れ子の型 | `State`・`Input`・`Output`・`Dependencies` は、値と同じ順 |
| 4 | 計算プロパティと関数 | `override` が先。続けて公開・internal・private の順 |
| 5 | `companion object` | |

次の物は、計算プロパティに数える。

| 計算プロパティに数える物 | 例 |
| --- | --- |
| getter のあるプロパティ | `val total: Int get() = ...` |
| 使う時に値を作る委譲 | `by lazy`・`by derivedStateOf` |

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| K3 | 区画の順 | クラスの中は、表の順に並べる。protected は internal と同じ所に置く |
| K3 | 画面のモデルの値 | `state`・`input`・`output`・`dependencies` の順にする |
| K3 | 画面のモデルの型 | `State`・`Input`・`Output`・`Dependencies` の順にする |
| K4 | 深さ | 入れ子の型は 2 段までにする。`A.B.C` までは書け、その中に型を宣言しない |
| K4 | 数えない物 | `companion object` と `enum` の値は、段に数えない |

`!!` と `require`・`check` を使わず、正しい値だけを作れる型で表す。

```kotlin
class BackupModel(
    private val clock: Clock,
) : ScreenPerforming {
    val state = State()
    val input = Input()

    private val dependencies = Dependencies(clock)

    class State {
        var file: BackupFile? by mutableStateOf(null)
            internal set
    }

    class Input

    private class Dependencies(
        val clock: Clock,
    )

    override suspend fun perform(action: Action) {
        read()
    }

    private suspend fun read() {
        state.file = load()
    }

    companion object {
        const val LIMIT = 10
    }
}
```

## 宣言の空行

ファイルとクラスの中の宣言は、次の決まりで並べる。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| K6 | 複数行 | 複数行にわたる宣言は、前後に空行を入れる |
| K6 | 1 行 | 同じまとまりの 1 行の保存プロパティは、空行を入れずに続ける |
| K6 | 順 | 同じまとまりの中では、1 行の保存プロパティを、複数行の保存プロパティより前に置く |

まとまりは、アクセス・`val` と `var`・委譲の種類・setter のアクセス・`const` が同じ保存プロパティを指す。

| 決まりの言葉 | 指すもの |
| --- | --- |
| 複数行の宣言 | 注釈の行を含めて 2 行以上の宣言。`internal set` を付けた 2 行の宣言も含む |
| 関数と型の前の空行 | ktlint の `blank-line-before-declaration` が見る。この決まりは、それと食い違わない |

```kotlin
class Layout {
    var width = 0
    var height = 0

    var insets = listOf(
        16,
        0,
    )

    var selection by mutableStateOf(0)
        internal set
}
```

## 文の空行

ブロックの中の文は、段落で分ける。「ブロック」は、`{ }` の中の文の並びを指す。

| 段落 | 入る文 |
| --- | --- |
| 準備 | 1 行の `val`・`var`。`?: return` で抜ける `val` も含む |
| 実行 | 1 行の代入と呼び出し |
| 親の呼び出し | `super.` で始まる 1 行の文 |
| 出口 | 1 行の `return`・`throw`・`break`・`continue` と、`if (...) return` |
| 結果 | 値を返すブロックの、最後の 1 行の式 |
| 複数行の文 | `if`・`when`・`for`・`try` と、複数行にわたる文。中の関数と型 |

値を返すブロックは、次の物を指す。

| 値を返すブロック | 例 |
| --- | --- |
| 値を返すラムダ | `map`・`let`・`remember` などに渡すラムダ |
| 値として使う `when` の分岐と `if` の式 | `val kind = when (type) { ... }` |
| 値として使う `try` | `val value = try { ... } catch ...` |

空行は、次の決まりで入れる。入れる所と入れない所のほかに、選べる所は無い。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| K7 | 複数行 | 複数行の文は、前後に空行を入れる。複数行の `val` も、`val` の並びの中で同じに扱う |
| K7 | 段落の境目 | 段落が変わる所には、空行を入れる |
| K7 | 段落の中 | 同じ段落の 1 行の文の間には、空行を入れない。代入と呼び出しは、同じ段落として続ける |
| K7 | 短いブロック | 1 行の文が 3 つまでのブロックには、段落が変わっても空行を入れない。init の本体と、親の呼び出しのあるブロックは除く |
| K7 | `val` と出口 | 1 行の `val` の並びと、最後の 1 行の出口だけのブロックには、数によらず空行を入れない |
| K7 | 結果 | 2 文以上の値を返すブロックは、最後の式の前に必ず空行を入れる。短いブロックの決まりより優先する |
| K8 | 長さ | 1 つの関数・init・getter は、60 行までにする。Composable も同じにする |

全部の分岐が 1 行の `when` だけでできた関数と getter は、長さを見ない。init の代入の間の空行は、検査で見ない。

```kotlin
fun start(model: EntryModel) {
    val source = dependencies.source ?: return

    input.source = source
    state.startListening()

    try {
        source.start()
    } catch (error: IOException) {
        reset()
    }
}

val totals = items.map { item ->
    val price = item.price * item.count

    price - item.discount
}

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    enableEdgeToEdge()
}
```

## Composable の本体

Composable の関数の本体は、次の段を上から順に並べる。

| 順 | 段 | 置くもの |
| --- | --- | --- |
| 1 | 持つ val | `Local...current`・モデル・`remember` の値 |
| 2 | 派生の val | 持つ値や引数から作る値 |
| 3 | 効果 | `LaunchedEffect`・`SideEffect` など、名前が `Effect` で終わる Composable |
| 4 | 組み立て | 画面の要素の呼び出し |

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| K9 | 段の順 | 段は、表の順に並べる。持つ val の段の中の順は決めない |

```kotlin
@Composable
fun MainView(link: Link?) {
    val model = rememberMainModel()
    val title = model.output.title

    LaunchedEffect(link) {
        model.open(link)
    }

    MainLayers(title = title)
}
```

## 守らせる仕組み

検査は `hooks/kotlin-layout-check.py` が行う。`.kt` を Edit・Write した後に走る。アプリの `make verify` は、追跡している全部の `.kt` に同じ検査をかける。

検査の範囲は、次のとおりである。

- 検査は、ktlint の jar に入っている Kotlin の構文木を、Java の小さなコマンドから読む。中身は `lib/hooks/kotlin_layout_check/` にある。
- 組むには `ktlint` と JDK が要る。`--release 17` で組み、Java 17 以上で動く。
- テストのファイルと、リポジトリの `.claude/` の下は見ない。
- 文の空行は、画面を組み立てるラムダの中と `@Preview` を見ない。大文字で始まる呼び出しに渡すラムダである。
- 組み立てのラムダの中でも、効果と `on` で始まる引数のラムダは、文の空行を見る。
- 組み立てのラムダの空行は、kotlin-style-check が `kotlin-compose.md` の決まりで見る。
- 値を返すラムダは、呼び出しの名前で見分ける。見分けられないラムダは、最後の式の前の空行を見ない。
- 1 行に収まるラムダは、文の空行を見ない。
- 持つ val と派生の val の見分けがつかない値は、Composable の本体の順で見ない。モデルの中身を読む値と、`animate...AsState` の値である。

今ある外れは、基準線に書いて見送れる。基準線は、アプリの `.claude/kotlin-layout-baseline.txt` である。

| 場面 | 検査がすること |
| --- | --- |
| 外れが基準線にある | 通す |
| 外れが基準線に無い、または数が増えた | NG にする |
| 基準線の外れが直った | `make verify` で NG にする。その行を消す |
| 基準線を作り直す | `kotlin-layout-check.py --write-baseline` に直したファイルを渡す |
| 検査のコマンドを組んでいない | `make verify` は組んでから見る。フックは、知らせて飛ばす |
| 外れをまとめて直す | `kotlin-layout-check.py --fix` にファイルを渡す。直した後に `ktlint --format` を通す |

`--fix` は、動きを変えない並べ替えだけを行う。直す物と直さない物は、次のとおりである。

| 決まり | `--fix` がすること |
| --- | --- |
| K1・K2・K3 | 宣言を、付いたコメントと注釈ごと区画の順に並べ替える。値を作る順が変わる時と、間にコメントがある時は動かさない |
| K6・K7 | 空行を足し、消す。1 行の宣言を前に動かすことはしない |
| K3 の画面のモデル | 値を作る順が変わるので、直さない |
| K4・K8・K9 | 直さない。手で直す |

次のことは、検査で見ない。レビューで見る。

- `val` は、使う文の近くに置く。値を先に取っておく必要がある時だけ、前に置く。
- 拡張だけのファイルの名前は、code-design-check が見る範囲だけを確かめる。
- 複数行の `val` と 1 行の `val` が交互に続く時は、変換を小さい関数に出す。
