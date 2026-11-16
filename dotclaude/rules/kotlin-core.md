---
paths:
  - "**/*.kt"
  - "**/*.kts"
---

# Kotlin の書き方

Kotlin を読み書きする時に読み込まれる決まり。宣言の置き方・名前を付ける値・改行と空行・ファイルとフォルダを決める。

| ほかの決まり | 置き場所 |
| --- | --- |
| Jetpack Compose の画面 | `kotlin-compose.md` |
| テスト | `kotlin-test.md` |
| 整形で直る決まり | リポジトリの ktlint。設定は最後の節の表に合わせる |

## 宣言の置き方

クラスの中身は、次の順に並べる。

| 順 | 置くもの |
| --- | --- |
| 1 | 入れ子の型（`sealed interface`・`enum class`・`data class` など） |
| 2 | プロパティ |
| 3 | `init` と副コンストラクタ |
| 4 | 関数 |
| 5 | `companion object` |

並びの中は、次の決まりでまとめる。

- プロパティと関数のそれぞれの中は、public から private の順に並べる。`override` は、同じアクセスの範囲の先頭に置く。
- プロパティは、アクセスの範囲と `val`・`var` が同じものでまとめる。`private set` を付けたものは、付けないものと分ける。
- 委譲（`by mutableStateOf` など）のプロパティも、委譲の種類が同じものでまとめる。まとまりの間には空行を入れる。
- 同じまとまりの中では、1 行の宣言を続けて並べ、複数行の宣言の間に挟まない。新しく置く時は、1 行の宣言を先に置く。
- 拡張関数と拡張プロパティは、型の外のトップレベルに置く。並びは public・internal・private の順にする。
- `!!` と `require`・`check` を使わず、正しい値だけを作れる型やファクトリで表す。テストとパースの失敗は `error(...)` でよい。

型は、種類で次の形に書く。

| 型の種類 | 書き方 |
| --- | --- |
| 値の型 | `data class`。中身が 1 つで型を分けたいだけなら `@JvmInline value class` |
| 決まった値の並び | `enum class`。値は小文字で始める（`budget`） |
| 中身の違う場合の並び | `sealed interface`。中身の無い場合は `data object` |
| 名前空間 | `object` |

## 改行

改行は、1 行を 100 字までにし、対象ごとに次の決まりで入れる。折り返せない文字列だけは、100 字を超えてよい。

### 宣言と呼び出しの引数

引数は、数と入れ子で折り返すかを決める。折り返した引数の最後には、カンマを付ける。

- 引数が 2 つ以上ある関数とコンストラクタの宣言は、100 字に収まっても 1 行に 1 つずつ書く。
- 引数が 1 つの宣言は、100 字に収まれば 1 行に書く。
- 名前付きで 2 つ以上の引数を渡す呼び出しは、1 行に 1 つずつ折り返す。
- 並んで同じ役割をする呼び出しと宣言は、1 つでも折り返したら、ほかも折り返す。`val` の並びもこれに当たる。
- 100 字に収まる呼び出し・`for`・`if` の式は、折り返さない。並ぶものにそろえる時だけ折り返す。
- 引数の中の呼び出しの引数が 2 つ以上なら、外も中も 1 行に 1 つずつ折り返す。`Modifier` のつなぎは除く。

### when とラムダ

ブロックは、中身が処理かどうかで 1 行に書くかを決める。

- 値を返すだけの `when` は、`->` の後ろを 1 行で書く。代入する時は `=` と同じ行に `when` を書く。
- `->` の後ろを `{ }` で次の行から書く `when` は、分岐の間に空行を入れる。
- すべての分岐を 1 行で書く `when` は、続けて書く。
- 中身の無いラムダは、`{}` と 1 行で書く。
- 処理を行うラムダは、中身を改行して書く。値を変えるだけの短いラムダ（`map` など）は 1 行でよい。
- 複数行のラムダの引数は、`it` を使わず名前を付ける。1 行のラムダは `it` でよい。
- 末尾のラムダにプロパティをつなぐ時は、閉じ括弧と同じ行に書く。
- 末尾のラムダに関数をつなぐ時は、閉じ括弧の次の行から 1 行に 1 つずつ並べる。

### 早く抜ける

早く抜ける処理は、次の形で書く。

- 値を取り出して抜ける時は、`?: return` を付けて 1 行で書く。
- 条件で抜ける時は、`if` の中の次の行に `return` を置く。
- 抜けた後の処理との間には、空行を入れる。抜ける行が続く時も、その間に空行を入れる。

```kotlin
val database = (launch as? Launch.Ready)?.database ?: return

if (launch != Launch.Failed) {
    return
}

today = currentDay()
```

### 長い式

整形で式の途中が切れる時は、`val` で名前を付けて分ける。`if` の式は、`Modifier` の引数に入れない。

### 改行の例

処理を行うラムダと、入れ子の呼び出しは、次の形で書く。

```kotlin
HomeView(
    model = home,
    onOpenEntry = { id ->
        sheet = Sheet.Edit(id)
    },
)

EntrySheet(
    model = EntryModel(
        database = database,
        date = home.today,
    ),
)
```

## val で名前を付ける値

`val` で名前を付けるかどうかは、次の決まりで決める。

- 引数の中で値を組み立てず、`val` で名前を付けてから渡す。
- `listOf(...)` のようにリテラルを並べるだけの値と、Compose の画面の組み立ては、引数の中に書いてよい。
- 込み入った式は、`val` で名前を付けてから `return` する。
- 1 回しか使わず引数にも渡さない値には、`val` を作らない。
- 関数をつなぐ起点と `if` の条件は、`val` にせずその場に書く。

## 空行

空行は、次の決まりで入れる。「ブロック」は、`{ }` の中の文の並びを指す。

- 1 行の文が 3 つまでのブロックは、空行を入れずに続けて書く。種類が変わっても入れない。`init` の本体は除く。
- 1 行の `val` の並びと、最後の 1 行の `return` だけのブロックは、数によらず空行を入れない。
- それより長いブロックの文は、下の表の種類でまとめ、種類が変わるところに空行を入れる。
- 同じ種類の呼び出しでも、対象が変わるところには空行を入れる。同じ役割の呼び出しは、続けて書く。
- `super` の呼び出しは、ほかの文と空行で分ける。短いブロックでも分ける。
- 複数行にわたる文（`val` を含む）がある時は、その前後と `return` の前に空行を入れる。
- 並んで同じ役割をする代入と呼び出しは、1 つでも複数行にわたるなら、すべての間に空行を入れる。
- クラスの中の複数行にわたるプロパティの宣言は、前後に空行を入れる。

文の種類は、次のとおりである。

| 種類 | 含むもの |
| --- | --- |
| `val` | |
| `var` | |
| 代入 | |
| 呼び出し | `launch` などのコルーチンを始める呼び出しも含む |
| 制御文 | `if`・`when`・`for`・`while`・`try` |
| `return` | `?: return` で抜ける `val` は、`val` に入れる |

短いブロックと `super` は、次の形で書く。

```kotlin
val palette: ThemePalette
    get() {
        val isDark = colorScheme == ColorScheme.dark
        return look.palette(isDark = isDark)
    }

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    enableEdgeToEdge()
    setContent { RootView() }
}
```

## ファイルとフォルダ

ファイルとフォルダは、ファイルの一覧でアルファベット順に並ぶことを前提に、次の決まりで名前を付ける。

| 決まり | 中身 |
| --- | --- |
| パッケージ | フォルダの名前を小文字でつないだものにし、フォルダの場所と合わせる |
| フォルダ | 小文字で、単語をつないで書く（`appfeature`・`designsystem`） |
| ファイル | 中の型の名前にする。型の拡張だけのファイルは `<型><役割>.kt` にする |
| 1 つの型 | 公開する型は、1 つのファイルに 1 つだけ置く。その型だけが使う `private` な型は、同じファイルに置く |
| 並び | 関係するファイルは、頭に元の型の名前を付けて隣に並べる |
| 同じ名前 | 同じファイル名を、別のフォルダやモジュールで使わない |
| 分ける大きさ | 1 つのファイルが 400 行を超えたら、役割ごとに `<型><役割>.kt` へ分ける |
| iOS との対応 | iOS と同じものを書く時は、iOS の型とファイルの名前にそろえる |

## ktlint の設定

リポジトリに ktlint を置く時は、上の決まりに合わせて、`.editorconfig` を次のとおりにする。

| 設定 | 値 | 合わせる決まり |
| --- | --- | --- |
| `ktlint_code_style` | `ktlint_official` | 整形の基本の形 |
| `max_line_length` | `100` | 1 行は 100 字まで |
| `ij_kotlin_allow_trailing_comma` | `true` | 折り返した引数の最後のカンマ |
| `ij_kotlin_allow_trailing_comma_on_call_site` | `true` | 折り返した引数の最後のカンマ |
| `ktlint_standard_enum-entry-name-case` | `disabled` | enum の値は小文字で始める |
| `ktlint_function_naming_ignore_when_annotated_with` | `Composable` | Composable の関数は大文字で始める |
| `ktlint_standard_filename` | `disabled` | 拡張だけのファイルを `<型><役割>.kt` にする |
| `ktlint_function_signature_rule_force_multiline_when_parameter_count_greater_or_equal_than` | `2` | 引数が 2 つ以上の宣言の折り返し |
| `ktlint_function_signature_body_expression_wrapping` | `default` | 式で書く関数の本文は、収まれば `=` と同じ行に置く |
| `ktlint_standard_multiline-expression-wrapping` | `disabled` | `=` と同じ行に `when` や呼び出しを書く |
| `ktlint_standard_string-template-indent` | `disabled` | 上の決まりを外すと、一緒に外す |
| `ktlint_standard_chain-method-continuation` | `disabled` | つないだ関数を 1 行に 1 つずつ並べる |
| `ktlint_standard_property-naming` | `disabled` | 定数も小文字で始める |
