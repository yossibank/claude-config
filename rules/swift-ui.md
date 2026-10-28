---
paths:
  - "**/AppFeature/**/*.swift"
  - "**/AppWidget/**/*.swift"
  - "**/DesignSystem/**/*.swift"
  - "**/Features/**/*.swift"
  - "**/*View.swift"
---

# SwiftUI の書き方

SwiftUI の画面と部品を読み書きするときに読み込まれる決まり。`swift-core.md` に足して決める。

| 節 | 決めること |
| --- | --- |
| 画面 | `View` の型の分け方、ビューの並べ方 |
| 文字と並び | 文字の縮め方と、収まらないときの並び |

## 画面

`View` の型は、次の決まりで書く。

- 画面の部品と処理は、別々の `private extension` に分け、部品を先に置く。処理は `Binding`、保存などの操作、表示用の値の計算である
- 1 つの要素だけで 1 か所でしか使わない部品は、プロパティや関数に分けず `body` に書く。ボタン 1 つ、`Picker` 1 つなどである
- `#Preview` は、ファイルの最後に置く
- 余白・間隔・角の丸みは、4 の倍数にする。2 以下の細かい調整と、部品の大きさ（`frame`）・ずらし（`offset`）・線の太さは除く
- ビューを並べるところは、`Spacer` も含め、ビューの間に必ず空行を入れる。`VStack`・`HStack`・`#Preview` などである

ビューの並びは、次の形で書く。

```swift
HStack {
    title

    Spacer()

    days
}
```

## 文字と並び

1 行に収める文字と、幅や高さで形を変える並びは、次の決まりで書く。

- `.lineLimit(1)` を付けた文字には、縮める倍率の下限を付ける。下限は、下の表の文字の種類で決める
- `ViewThatFits` の候補に、`ForEach` を含むビューを入れない
- 収まらないときだけスクロールさせるときは、`ViewThatFits` で中身とその `ScrollView` 版を並べない。`ScrollView` 1 つに入れ、`.scrollBounceBehavior(.basedOnSize)` を付ける

| 文字の種類 | 最小の倍率 |
| --- | --- |
| 下の 2 つ以外の文字 | `.minimumScaleFactor(0.8)` |
| `displayFont` で出す金額、アイコンの中の文字、ウィジェットの文字 | 枠に収まる値まで下げる。下限は 0.5 にする |
| 一覧の行・格子の札・同じ行の札に並ぶ、使う人が決める名前 | 別々に縮めず、並びの中で一番縮んだ大きさにそろえる。DesignSystem の倍率をそろえる修飾子を、名前と並びに付ける |
