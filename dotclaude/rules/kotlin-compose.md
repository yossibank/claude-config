---
paths:
  - "**/appfeature/**/*.kt"
  - "**/appwidget/**/*.kt"
  - "**/designsystem/**/*.kt"
  - "**/features/**/*.kt"
  - "**/*View.kt"
---

# Jetpack Compose の書き方

Compose の画面と部品を読み書きする時に読み込まれる決まり。`kotlin-core.md` に足して、Composable の分け方と文字の縮め方を決める。

## 画面

Composable の関数は、次の決まりで書く。

- 画面の部品は、同じファイルの `private` な Composable に分ける。公開する Composable の後に置く。
- 状態の変え方と保存などの操作は、画面のモデルに置く。モデルは `ViewModel` か状態のクラスである。
- 1 つの要素だけで 1 か所でしか使わない部品は、関数に分けずにその場に書く。ボタン 1 つ、`Switch` 1 つなどである。
- 公開する Composable は、省ける引数の先頭に `modifier` を置く。初めの値は `Modifier` にする。
- 受けた `modifier` は、いちばん外の要素に渡す。
- 動きを受けるラムダの引数は、`on<動き>` と名付ける。
- 中身を受けるラムダの `content` は、最後の引数にする。
- `@Preview` は、ファイルの最後に置く。
- 余白・間隔・角の丸みは、4 の倍数の `dp` にする。2 以下の細かい調整と、大きさ（`size`）・ずらし（`offset`）・線の太さは除く。
- 要素を並べるところは、`Spacer` も含め、要素の間に空行を入れる。`Column`・`Row`・`Box` などである。kotlin-style-check が確かめる。
- 同じ Composable の 1 行の呼び出しだけが続く時は、空行を入れない。kotlin-style-check が確かめる。
- 複数行の呼び出しを含む並びは、すべての間に空行を入れる。kotlin-style-check が確かめる。
- `Modifier` のつなぎは、2 つ以上なら `Modifier` の次の行から 1 行に 1 つずつ並べる。

要素の並びは、次の形で書く。

```kotlin
Row {
    Title()

    Spacer(modifier = Modifier.weight(1f))

    Days()
}

Row {
    ChipButton(title = "今日", onClick = {})
    ChipButton(title = "昨日", onClick = {})
}
```

## 文字と並び

1 行に収める文字と、幅や高さで形を変える並びは、次の決まりで書く。

- `maxLines = 1` を付けた文字には、DesignSystem の縮める仕組みで倍率の下限を付ける。下限は下の表で決める。
- 幅を中身に合わせる文字（`wrapContentWidth` など）は、縮めない。
- 一覧の行・格子の札・同じ行の札に並ぶ、使う人が決める名前は、別々に縮めない。DesignSystem の倍率をそろえる仕組みを、並びに付ける。
- 収まらない時だけスクロールさせる時は、`verticalScroll` か `LazyColumn` 1 つに入れる。中身とスクロール版を並べて選ばない。

| 文字の種類 | 縮める倍率の下限 |
| --- | --- |
| `displayFont` で出す金額、アイコンの中の文字、ウィジェットの文字 | 枠に収まる値まで下げる。下限は 0.5 にする |
| ほかの文字 | 0.8 |
