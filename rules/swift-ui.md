---
paths:
  - "**/AppFeature/**/*.swift"
  - "**/AppWidget/**/*.swift"
  - "**/DesignSystem/**/*.swift"
  - "**/Features/**/*.swift"
  - "**/*View.swift"
---

# SwiftUI の書き方

SwiftUI の画面と部品を読み書きするときに読み込まれる決まり。`swift-core.md` に足して、`View` の型の分け方、ビューの並べ方、文字の縮め方と、収まらないときの並びを決める。

## 画面

`View` の型は、次の決まりで書く。

- 画面の部品と、処理（`Binding`、保存などの操作、表示用の値の計算）は、別々の `private extension` に分ける。部品の extension を先に置く
- 1 つの要素だけで 1 か所でしか使わない部品（ボタン 1 つ、`Picker` 1 つなど）は、プロパティや関数に分けず `body` に書く
- `#Preview` は、ファイルの最後に置く
- 余白・間隔・角の丸みは、4 の倍数にする。2 以下の細かい調整と、部品の大きさ（`frame`）・ずらし（`offset`）・線の太さは除く
- ビューを並べるところ（`VStack`・`HStack`・`#Preview` など）は、`Spacer` も含め、ビューの間に必ず空行を入れる

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

- `.lineLimit(1)` を付けた文字には、`.minimumScaleFactor(0.8)` を付ける。次のものは除く
  - `displayFont` で出す金額、アイコンの中の文字、ウィジェットの文字は、枠に収まる値まで下げる。下限は 0.5 にする
  - 一覧の行・格子の札・同じ行の札に並ぶ、使う人が決める名前は、別々に縮めない。並びで倍率をそろえる DesignSystem の修飾子を名前と並びに付け、並びの中で一番縮んだ大きさにそろえる
- `ViewThatFits` の候補に、`ForEach` を含むビューを入れない
- 収まらないときだけスクロールさせるときは、`ViewThatFits` で中身とその `ScrollView` 版を並べない。`ScrollView` 1 つに入れ、`.scrollBounceBehavior(.basedOnSize)` を付ける
