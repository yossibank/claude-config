#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"
source "$(dirname "$0")/../support/hook_fixtures.sh"

style_case() {
    local expect=$1 label=$2 text=$3 want=${4:-}
    [[ $expect != 2 || -n $want ]] || want="Swift の決まり（rules/swift-*.md）に合わない箇所がある"
    hook_case swift-style-check "$expect" "$label" "$work/Case.swift" "$text" "$want"
}

style_case 2 "&& のある三項演算子を 1 行に書けば止める" $'var a: Int {\n    b && c ? 1 : 2\n}' "Case.swift:2: 条件に && か ||"
style_case 0 "&& のある三項演算子を折り返せば通る" $'var a: Int {\n    b && c\n        ? 1\n        : 2\n}'
style_case 0 "条件が 1 つの三項演算子は 1 行で通る" $'var a: Int {\n    b ? 1 : 2\n}'
style_case 0 "三項演算子の条件の外にある && は見ない" $'func a() {\n    if b && c { d = e ? 1 : 2 }\n    f(g && h, i ? 1 : 2)\n}'
style_case 2 "代入の後ろの条件にある && で止める" $'func a() {\n    b = c == d && e ? 1 : 2\n}' "Case.swift:2: 条件に && か ||"
style_case 0 "文字列とコメントの中の && と ? は見ない" $'let a = "x && y ? 1 : 2" // b || c ? 1 : 2'

style_case 2 "比べる式の途中で切れたメンバーの参照を止める" $'func a() {\n    b = c == d && e == f\n        .g\n}' "Case.swift:2: 式の途中が整形で切れている"
style_case 2 "< の後ろで切れた式も止める" $'func a() {\n    let b = c || d.e(f) < g\n        .e(h)\n}' "Case.swift:2: 式の途中が整形で切れている"
style_case 0 "let で名前を付けて分ければ通る" $'func a() {\n    let g = f.g\n    b = c == d && e == g\n}'
style_case 0 "#if の条件の後ろのモディファイアは見ない" $'var a: some View {\n    Text("a")\n    #if DEBUG || TESTING\n        .padding()\n    #endif\n}'
style_case 0 "代入の右から始まるメソッドのつなぎは通る" $'func a() {\n    let b = items\n        .filter { $0.c }\n}'

style_case 2 "else if の条件を , で折り返せば止める" $'func a() {\n    if b {\n    } else if c,\n              d {\n    }\n}' "Case.swift:3: else if の条件は 1 つ"
style_case 2 "else if の条件を , で 1 行に並べても止める" $'func a() {\n    if b {\n    } else if let c, d {\n    }\n}' "Case.swift:3: else if の条件は 1 つ"
style_case 0 "else if の条件が 1 つなら通る" $'func a() {\n    if b, c {\n    } else if d {\n    }\n}'
style_case 0 "else if の条件の括弧の中の , は見ない" $'func a() {\n    if b {\n    } else if f(c, d) {\n    }\n}'

style_case 2 "引数が 1 つの宣言を、収まるのに折り返せば止める" $'func a(\n    b: Int\n) {}' "Case.swift:1: 引数が 1 つの宣言"
style_case 0 "引数が 1 つの宣言を 1 行に書けば通る" $'func a(b: Int) {}'
style_case 0 "引数が 2 つの宣言は折り返して通る" $'func a(\n    b: Int,\n    c: Int\n) {}'
exact=$(printf 'x%.0s' {1..84})
style_case 2 "1 行にするとちょうど 100 字の宣言を折り返せば止める" "func a(
    ${exact}: Int
) {}" "Case.swift:1: 引数が 1 つの宣言"
long=$(printf 'x%.0s' {1..85})
style_case 0 "1 行にすると 101 字になる宣言は折り返して通る" "func a(
    ${long}: Int
) {}"

style_case 2 "同じ型の 1 行のビューの間に空行があれば止める" $'var a: some View {\n    VStack {\n        Text("a")\n\n        Text("b")\n    }\n}' "Case.swift:5: 同じ型の 1 行のビュー"
style_case 0 "同じ型の 1 行のビューを続けて書けば通る" $'var a: some View {\n    HStack {\n        Text("a")\n        Text("b")\n    }\n}'
style_case 2 "型が変わるビューの間に空行が無ければ止める" $'var a: some View {\n    HStack {\n        Text("a")\n        Spacer()\n    }\n}' "Case.swift:4: 型が変わるビュー"
style_case 2 "複数行のビューを含む並びに空行が無ければ止める" $'var a: some View {\n    VStack {\n        Text("a")\n            .bold()\n        Text("b")\n    }\n}' "Case.swift:5: 型が変わるビュー"
style_case 0 "型が変わるビューの間に空行があれば通る" $'var a: some View {\n    HStack {\n        Text("a")\n\n        Spacer()\n    }\n}'
style_case 0 "let を含むビューの並びは見ない" $'#Preview {\n    let a = 1\n    Text("a")\n}'

style_case 0 "補間の中の入れ子の文字列も、文字列として見ない" 'let a = "\(c ? "x && y ? 1 : 2" : "z")"'
style_case 2 "補間のある文字列の後ろの三項演算子は見る" $'let a = "\\(b)"; let c = d && e ? 1 : 2' "Case.swift:1: 条件に && か ||"

style_case 2 "var の後に空行なしで let を置けば止める" $'struct A {\n    public var b = 1\n    let c: Int\n}' "Case.swift:3: 保存プロパティのまとまり"
style_case 2 "let の後に空行なしで private let を置けば止める" $'struct A {\n    let b: Int\n    private let c: Int\n}' "Case.swift:3: 保存プロパティのまとまり"
style_case 2 "extension の中でも、プロパティラッパーが変われば止める" $'extension A {\n    @State private var b = 1\n    private var c = 2\n}' "Case.swift:3: 保存プロパティのまとまり"
style_case 2 "static と static でないものの間に空行が無ければ止める" $'struct A {\n    static let b = 1\n    let c = 2\n}' "Case.swift:3: 保存プロパティのまとまり"
style_case 2 "didSet を持つプロパティは保存プロパティとして見る" $'struct A {\n    var b = 1 {\n        didSet {}\n    }\n    let c = 2\n}' "Case.swift:5: 保存プロパティのまとまり"
style_case 0 "まとまりの間に空行があれば通る" $'struct A {\n    public var b = 1\n\n    let c: Int\n}'
style_case 0 "同じまとまりが続けば通る" $'struct A {\n    public var b = 1\n    public var c = 2\n\n    static let d = 3\n    static let e = 4\n}'
style_case 0 "計算プロパティを挟めば見ない" $'struct A {\n    var b = 1\n    var c: Int { 2 }\n    let d = 3\n}'
style_case 0 "関数の中の let と var は見ない" $'struct A {\n    func a() {\n        var b = 1\n        let c = 2\n    }\n}'
style_case 0 "class func の中の let と var は見ない" $'final class A: XCTestCase {\n    override class func setUp() {\n        let b = 1\n        var c = 2\n        c += b\n    }\n}'
style_case 0 "class var の getter の中の let と var は見ない" $'final class A {\n    class var shared: Int {\n        let b = 1\n        var c = 2\n        c += b\n        return c\n    }\n}'

finish
