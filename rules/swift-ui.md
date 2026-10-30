---
paths:
  - "**/AppFeature/**/*.swift"
  - "**/AppWidget/**/*.swift"
  - "**/DesignSystem/**/*.swift"
  - "**/Features/**/*.swift"
  - "**/*View.swift"
---

# SwiftUI の書き方

SwiftUI の画面と部品を読み書きする時に読み込まれる決まり。`swift-core.md` に足して、`View` の分け方と文字の縮め方を決める。

## 画面

`View` の型は、次の決まりで書く。

- 画面の部品と処理は、別々の `private extension` に分け、部品を先に置く。処理は `Binding`、保存などの操作、表示用の値の計算である。
- 1 つの要素だけで 1 か所でしか使わない部品は、プロパティや関数に分けず `body` に書く。ボタン 1 つ、`Picker` 1 つなどである。
- `#Preview` は、ファイルの最後に置く。
- 余白・間隔・角の丸みは、4 の倍数にする。2 以下の細かい調整と、部品の大きさ（`frame`）・ずらし（`offset`）・線の太さは除く。
- ビューを並べるところは、`Spacer` も含め、ビューの間に必ず空行を入れる。`VStack`・`HStack`・`#Preview` などである。

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

- `.lineLimit(1)` を付けた文字には、縮める倍率の下限を付ける。下限は下の表で決め、使う人が決める名前は次の項目に従う。
- 一覧の行・格子の札・同じ行の札に並ぶ、使う人が決める名前は、別々に縮めない。DesignSystem の倍率をそろえる修飾子を、名前と並びの両方に付ける。
- `ViewThatFits` の候補に、`ForEach` を含むビューを入れない。
- 収まらない時だけスクロールさせる時は、`ViewThatFits` で中身とその `ScrollView` 版を並べない。`ScrollView` 1 つに入れ、`.scrollBounceBehavior(.basedOnSize)` を付ける。

| 文字の種類 | 縮める倍率の下限 |
| --- | --- |
| `displayFont` で出す金額、アイコンの中の文字、ウィジェットの文字 | 枠に収まる値まで下げる。下限は 0.5 にする |
| ほかの文字 | `.minimumScaleFactor(0.8)` |
