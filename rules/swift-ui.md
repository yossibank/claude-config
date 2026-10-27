---
paths:
  - "**/AppFeature/**/*.swift"
  - "**/AppWidget/**/*.swift"
  - "**/DesignSystem/**/*.swift"
  - "**/Features/**/*.swift"
  - "**/*View.swift"
---

# SwiftUI の書き方

SwiftUI の画面と部品を読み書きするときに読み込まれる決まり。`swift-core.md` に足して、`View` の型の分け方とビューの並べ方を決める。

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
