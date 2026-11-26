---
paths:
  - "**/*.swift"
---

# Swift の並び

Swift を読み書きする時に読み込まれる決まり。ファイルの中の区画・extension の役割・宣言と文の空行を決める。

改行と名前は `swift-core.md`、画面は `swift-ui.md` にある。決まりの頭の番号は、検査が止める文の頭に出る。

## ファイルの区画

1 つのファイルは、次の区画を上から順に並べる。使わない区画は書かない。

| 順 | 区画 | 置くもの |
| --- | --- | --- |
| 1 | import | |
| 2 | 型の本体 | 保存プロパティ・`case`・init・`body` |
| 3 | 入れ子の型の宣言 | 型の宣言だけを置く extension |
| 4 | 外に見せる値と関数 | `public extension`・`package extension` と、無印の `extension` |
| 5 | 中だけの値と関数 | `private extension` |
| 6 | 入れ子の型の中身 | `extension <親>.<入れ子>` |
| 7 | 適合 | 実装のある適合の extension |
| 8 | ほかの型の extension | このファイルだけで使う補助 |
| 9 | `#Preview` | |

区画は、次の決まりで並べる。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| L1 | 区画の順 | 区画は、表の順に並べる。区画 3・4・6 の中は、public・無印・private の順にする |
| L1 | 置く場所 | ほかの型の extension は、このファイルの型の区画の後に置く。`#Preview` は最後に置く |
| L2 | 中身の種類 | 入れ子の型の宣言と、値・関数を同じ extension に置かない |
| L2 | 数 | 同じ型・同じ区画・同じアクセスの extension は、1 つにまとめる。`where` の違いと、区画 6 の型の宣言だけの extension は、別に数える |
| L2 | 画面 | 画面の `private extension` は、部品と処理の 2 つに分け、部品を先に置く |
| L5 | 適合 | 実装のある適合は、1 つの適合につき 1 つの extension にする。中身の無い適合は、宣言に並べて書く |

決まりの言葉は、次の物を指す。

| 言葉 | 指すもの |
| --- | --- |
| このファイルの型 | ファイルで宣言した型と、ファイルの名前の `+` より前に当たる型。`WalletKind+Title.swift` では `Wallet.Kind` |
| 部品 | 型が `some` で始まる計算プロパティと、`some` で始まる型を返す関数 |
| 処理 | 部品でない値と関数。`Binding`、操作、表示用の値の計算 |

区画は、次の形で並ぶ。

```swift
public final class BackupModel {
    public let state: State

    public init() {
        self.state = State()
    }
}

public extension BackupModel {
    final class State {
        public var file: BackupFile?
    }

    struct BackupFile: Equatable {
        public let name: String
    }
}

public extension BackupModel {
    func read() async {
        state.file = await load()
    }
}

private extension BackupModel {
    func load() async -> BackupFile? {
        nil
    }
}

public extension BackupModel.State {
    var hasFile: Bool {
        file != nil
    }
}

extension BackupModel.BackupFile: Identifiable {
    public var id: String {
        name
    }
}
```

## 型の本体と入れ子の型

型の本体には、持つ物だけを置く。入れ子の型も、同じ決まりで書く。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| L3 | 置ける物 | 型の本体には、保存プロパティ・`case`・init・`deinit` だけを置く。`body` は init の後に置く |
| L3 | 出す物 | 計算プロパティ・関数・添字・入れ子の型は、extension に出す |
| L4 | 深さ | 入れ子の型は 2 段までにする。`A.B.C` までは書け、その中に型を宣言しない |

次の物は、本体に置いてよい。

| 置いてよい物 | 例 |
| --- | --- |
| 観察の付いた保存プロパティ | `didSet`・`willSet` |
| `override` の付いた宣言 | extension では上書きできない |
| `final` でない class の関数・計算プロパティ・添字 | extension に出すと、子のクラスで上書きできない |
| `CodingKeys` | `Codable` の鍵の enum |
| SwiftUI が呼ぶ口 | `body`・`makeBody`・`makeUIView`・`path`・`placeSubviews`・`reduce`・`sizeThatFits`・`updateUIView` |
| 名前空間の enum の中身 | `case` の無い enum は、中身を全部本体に書く |

強制アンラップと `precondition` を使わず、正しい値だけを作れる型や init で表す。

## 宣言の空行

型の本体と extension の中の宣言は、次の決まりで並べる。保存プロパティのまとまりは、`swift-core.md` の「プロパティのまとまり」にある。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| L6 | 複数行 | 複数行にわたる宣言は、前後に空行を入れる |
| L6 | 1 行 | 同じまとまりの 1 行の保存プロパティは、空行を入れずに続ける |
| L6 | 順 | 同じまとまりの中では、1 行の保存プロパティを、複数行の保存プロパティより前に置く |

```swift
struct Layout {
    var size: CGSize = .zero
    var offset: CGFloat = 0

    var insets = EdgeInsets(
        top: 0,
        leading: 16,
        bottom: 0,
        trailing: 16
    )
}
```

## 文の空行

ブロックの中の文は、段落で分ける。「ブロック」は、`{ }` の中の文の並びを指す。

| 段落 | 入る文 |
| --- | --- |
| 準備 | 1 行の `let`・`var` |
| 実行 | 1 行の代入と呼び出し。`await` の文と、結果を捨てる `_ = ...` も含む |
| 親の呼び出し | `super.` で始まる 1 行の文 |
| 出口 | 1 行の `return`・`throw`・`break`・`continue` |
| 複数行の文 | `guard`・`if`・`for`・`switch`・`do`・`defer` と、複数行にわたる文 |

空行は、次の決まりで入れる。入れる所と入れない所のほかに、選べる所は無い。

| 番号 | 対象 | 決まり |
| --- | --- | --- |
| L7 | 複数行 | 複数行の文は、前後に空行を入れる。複数行の `let` も、`let` の並びの中で同じに扱う |
| L7 | 段落の境目 | 段落が変わる所には、空行を入れる |
| L7 | 段落の中 | 同じ段落の 1 行の文の間には、空行を入れない。代入と呼び出しは、同じ段落として続ける |
| L7 | 短いブロック | 1 行の文が 3 つまでのブロックには、段落が変わっても空行を入れない。init の本体と、親の呼び出しのあるブロックは除く |
| L7 | `let` と出口 | 1 行の `let` の並びと、最後の 1 行の出口だけのブロックには、数によらず空行を入れない |
| L8 | 長さ | 1 つの関数・init・計算プロパティは、60 行までにする。超える前に、段落を関数に出す |

全部の分岐が 1 行の `switch` だけでできた関数と計算プロパティは、長さを見ない。init は、`let` で作る値・プロパティラッパーへの代入・ほかの代入の順に並べる。init の代入の間の空行は、検査で見ない。

```swift
func start(for model: EntryModel) async {
    guard let source = dependencies.makeSource() else {
        return
    }

    let session = Session(model: model)

    input.source = source
    input.session = session
    state.startListening()

    do {
        try await source.start()
    } catch {
        reset()
    }
}

var palette: ThemePalette {
    let isDark = colorScheme == .dark
    return look.palette(isDark: isDark)
}

override func didMoveToWindow() {
    super.didMoveToWindow()

    observeStyle()
    apply()
}
```

## 守らせる仕組み

検査は `hooks/swift-layout-check.py` が行う。`.swift` を Edit・Write した後に走る。アプリの `make verify` は、追跡している全部の `.swift` に同じ検査をかける。

検査の範囲は、次のとおりである。

- 検査は、SwiftSyntax で構文木を読む。中身は `lib/hooks/swift_layout_check/package/` にある。
- テストのファイルと、リポジトリの `.claude/` の下は見ない。
- 文の空行は、画面を組み立てるブロックの中を見ない。型が `some` で始まる宣言・`Builder` で終わる属性の宣言・`#Preview` の中である。
- 画面を組み立てるブロックの空行は、`swift-ui.md` の決まりを swift-style-check が見る。
- 1 行に収まるクロージャと `case` は、文の空行を見ない。
- 関数の長さは、型と extension の中の宣言を見る。

今ある外れは、基準線に書いて見送れる。基準線は、アプリの `.claude/swift-layout-baseline.txt` である。

| 場面 | 検査がすること |
| --- | --- |
| 外れが基準線にある | 通す |
| 外れが基準線に無い、または数が増えた | NG にする |
| 基準線の外れが直った | `make verify` で NG にする。その行を消す |
| 基準線を作り直す | `swift-layout-check.py --write-baseline` に直したファイルを渡す |
| 検査のコマンドを組んでいない | `make verify` は組んでから見る。フックは、知らせて飛ばす |
| 外れをまとめて直す | `swift-layout-check.py --fix` にファイルを渡す。アプリの `make format` が呼ぶ |

`--fix` は、動きを変えない並べ替えだけを行う。直す物と直さない物は、次のとおりである。

| 決まり | `--fix` がすること |
| --- | --- |
| L1・L2 | extension を分け、まとめ、区画の順に並べ替える |
| L3 | 本体の値・関数・型を extension に出す。入れ子の型から出す時は、親の型の名前を補う |
| L6・L7 | 空行を足し、消す。1 行の宣言を前に動かすことはしない |
| L4・L5・L8 | 直さない。手で直す |

次のことは、検査で見ない。レビューで見る。

- `let` は、使う文の近くに置く。値を先に取っておく必要がある時だけ、前に置く。
- 適合の extension には、その適合の要求の実装だけを置く。
- 複数行の `let` と 1 行の `let` が交互に続く時は、変換を小さい関数に出す。
