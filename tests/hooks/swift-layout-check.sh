#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"

# HOME を差し替える前に組む。組めていないと、フックは検査を飛ばす
check "swift-layout を組める" swift build -c release --package-path "$root/lib/hooks/swift_layout_check/package"

source "$(dirname "$0")/../support/hook_fixtures.sh"

layout_case() {
    local expect=$1 label=$2 text=$3 want=${4:-}
    hook_case swift-layout-check "$expect" "$label" "$work/Case.swift" "$text" "$want"
}

# <行の数> の関数を持つ、名前空間の enum
long_function() {
    local out=$'enum Case {\n    static func a() {\n' i
    for ((i = 0; i < $1 - 2; i++)); do out+=$'        b()\n'; done
    printf '%s' "${out}"$'    }\n}'
}

layout_case 2 "L1: private extension の後に無印の extension を置けば止める" $'struct Case {}\n\nprivate extension Case {\n    var a: Int {\n        1\n    }\n}\n\nextension Case {\n    var b: Int {\n        2\n    }\n}' "Case.swift:9: L1: extension の順が違う。「外に見せる値と関数」は「private extension」より前に置く"
layout_case 0 "L1: 型の宣言・public・無印・private・入れ子・適合の順なら通る" $'struct Case {}\n\nextension Case {\n    struct Row {}\n}\n\npublic extension Case {\n    var a: Int {\n        1\n    }\n}\n\nextension Case {\n    var b: Int {\n        2\n    }\n}\n\nprivate extension Case {\n    var c: Int {\n        3\n    }\n}\n\nextension Case.Row {\n    var d: Int {\n        4\n    }\n}\n\nextension Case: Identifiable {\n    var id: Int {\n        5\n    }\n}'
layout_case 2 "L1: 入れ子の型の private extension の後に無印を置けば止める" $'struct Case {}\n\nextension Case {\n    struct Row {}\n}\n\nprivate extension Case.Row {\n    var a: Int {\n        1\n    }\n}\n\nextension Case.Row {\n    var b: Int {\n        2\n    }\n}' "Case.swift:13: L1: extension は public・無印・private の順に置く"
layout_case 2 "L1: ほかの型の extension を、ファイルの型より前に置けば止める" $'extension Other {\n    var a: Int {\n        1\n    }\n}\n\nstruct Case {}' "Case.swift:1: L1: ほかの型の extension は、このファイルの型の後に置く"
layout_case 0 "L1: 親の名前をつなげたファイルの extension は、ファイルの型と見る" $'extension Case.Kind {\n    var a: Int {\n        1\n    }\n}\n\nextension Other {\n    var b: Int {\n        2\n    }\n}'
layout_case 2 "L1: #Preview の後に宣言を置けば止める" $'struct Case {}\n\n#Preview {\n    Text("a")\n}\n\nextension Case: Identifiable {\n    var id: Int {\n        1\n    }\n}' "Case.swift:7: L1: #Preview は、ファイルの最後に置く"

layout_case 2 "L2: 入れ子の型の宣言と関数を同じ extension に置けば止める" $'struct Case {}\n\nextension Case {\n    struct Row {}\n\n    var a: Int {\n        1\n    }\n}' "Case.swift:3: L2: 入れ子の型の宣言と、値・関数を同じ extension に置かない"
layout_case 2 "L2: 同じ役割の extension が 2 つあれば止める" $'struct Case {}\n\nextension Case {\n    var a: Int {\n        1\n    }\n}\n\nextension Case {\n    var b: Int {\n        2\n    }\n}' "Case.swift:9: L2: 同じ役割の extension が 2 つある"
layout_case 0 "L2: where の違う extension は、別の役割と見る" $'struct Case<A> {}\n\nextension Case where A == Int {\n    var a: Int {\n        1\n    }\n}\n\nextension Case where A == String {\n    var b: Int {\n        2\n    }\n}'
layout_case 2 "L2: 部品と処理を 1 つの private extension に置けば止める" $'struct Case {}\n\nprivate extension Case {\n    var title: some View {\n        Text("a")\n    }\n\n    var count: Int {\n        1\n    }\n}' "Case.swift:3: L2: 画面の部品と処理を、別の private extension に分ける"
layout_case 2 "L2: 処理を部品より先に置けば止める" $'struct Case {}\n\nprivate extension Case {\n    var count: Int {\n        1\n    }\n}\n\nprivate extension Case {\n    var title: some View {\n        Text("a")\n    }\n}' "Case.swift:9: L2: 画面の部品と処理を、別の private extension に分ける"
layout_case 0 "L2: 部品、処理の順に private extension を分ければ通る" $'struct Case {}\n\nprivate extension Case {\n    var title: some View {\n        Text("a")\n    }\n}\n\nprivate extension Case {\n    var count: Int {\n        1\n    }\n}'

layout_case 2 "L3: 型の本体に計算プロパティを置けば止める" $'struct Case {\n    let a: Int\n\n    var b: Int {\n        a\n    }\n}' "Case.swift:4: L3: 型の本体には、保存プロパティ・case・init だけを置く。b は extension に出す"
layout_case 2 "L3: case のある enum の本体に関数を置けば止める" $'enum Case {\n    case a\n\n    func b() {}\n}' "Case.swift:4: L3: 型の本体には"
layout_case 2 "L3: 型の本体に入れ子の型を置けば止める" $'struct Case {\n    struct Row {}\n}' "Case.swift:2: L3: 型の本体には"
layout_case 0 "L3: 保存プロパティ・didSet・init・body・CodingKeys・override は本体に置ける" $'final class Case: Base, View {\n    static let limit = 1\n\n    var a = 1 {\n        didSet {}\n    }\n\n    enum CodingKeys: String, CodingKey {\n        case a\n    }\n\n    init() {}\n\n    var body: some View {\n        Text("a")\n    }\n\n    override func b() {}\n}'
layout_case 0 "L3: final でない class の関数・計算プロパティ・添字は本体に置ける" $'class Case {\n    var a: Int {\n        1\n    }\n\n    subscript(b: Int) -> Int {\n        b\n    }\n\n    func c() {}\n}'
layout_case 2 "L3: final でない class でも、入れ子の型は止める" $'class Case {\n    struct Row {}\n}' "Case.swift:2: L3: 型の本体には"
layout_case 0 "L3: case の無い enum は、名前空間として本体に書ける" $'enum Case {\n    static func a() {}\n}'
layout_case 0 "L3: protocol の要求は見ない" $'protocol Case {\n    var a: Int { get }\n\n    func b()\n}'

layout_case 2 "L4: 入れ子が 3 段になれば止める" $'struct Case {}\n\nextension Case {\n    struct A {}\n}\n\nextension Case.A {\n    struct B {}\n}\n\nextension Case.A.B {\n    struct C {}\n}' "Case.swift:12: L4: 入れ子の型は 2 段までにする"
layout_case 0 "L4: 入れ子が 2 段ちょうどなら通る" $'struct Case {}\n\nextension Case {\n    struct A {}\n}\n\nextension Case.A {\n    struct B {}\n}'

layout_case 2 "L5: 実装のある適合を 1 つの extension に 2 つ書けば止める" $'struct Case {}\n\nextension Case: Equatable, Identifiable {\n    var id: Int {\n        1\n    }\n}' "Case.swift:3: L5: 実装のある適合は"
layout_case 0 "L5: 中身の無い適合は、並べて書ける" $'struct Case {}\n\nextension Case: Equatable, Sendable {}'

layout_case 2 "L6: 複数行の宣言の後に空行が無ければ止める" $'struct Case {\n    let a = [\n        1\n    ]\n    let b = 2\n}' "Case.swift:5: L6: 複数行の宣言の前後には、空行を入れる"
layout_case 2 "L6: 1 行の宣言を複数行の宣言の後に置けば止める" $'struct Case {\n    let a = [\n        1\n    ]\n\n    let b = 2\n}' "Case.swift:6: L6: 1 行の宣言は、同じまとまりの複数行の宣言より前に置く"
layout_case 2 "L6: 同じまとまりの 1 行の宣言の間に空行があれば止める" $'struct Case {\n    let a = 1\n\n    let b = 2\n}' "Case.swift:4: L6: 同じまとまりの 1 行の宣言の間に、空行を入れない"
layout_case 0 "L6: まとまりが変わる所の空行と、1 行を先にした並びは通る" $'struct Case {\n    let a = 1\n    let b = 2\n\n    let c = [\n        3\n    ]\n\n    private var d = 4\n}'

layout_case 2 "L7: 1 行の文が 3 つまでのブロックに空行があれば止める" $'func a() {\n    b()\n\n    c()\n}' "Case.swift:4: L7: 1 行の文が 3 つまでのブロックには、空行を入れない"
layout_case 2 "L7: 同じ段落の 1 行の文の間に空行があれば止める" $'func a() {\n    b()\n    c()\n\n    d()\n    e()\n}' "Case.swift:5: L7: 同じ段落の 1 行の文の間に、空行を入れない"
layout_case 2 "L7: 準備と実行の間に空行が無ければ止める" $'func a() {\n    let b = 1\n    c(b)\n    d()\n    e()\n}' "Case.swift:3: L7: 段落（準備・実行・出口）が変わる所には、空行を入れる"
layout_case 2 "L7: 実行と出口の間に空行が無ければ止める" $'func a() -> Int {\n    b()\n    c()\n    d()\n    return 1\n}' "Case.swift:5: L7: 段落（準備・実行・出口）が変わる所には、空行を入れる"
layout_case 2 "L7: 複数行の文の前に空行が無ければ止める" $'func a() {\n    b()\n    if c {\n        d()\n    }\n}' "Case.swift:3: L7: 複数行の文の前後には、空行を入れる"
layout_case 2 "L7: 複数行の let の前に空行が無ければ止める" $'func a() -> Int {\n    let b = 1\n    let c = d(\n        b\n    )\n\n    return c\n}' "Case.swift:3: L7: 複数行の文の前後には、空行を入れる"
layout_case 2 "L7: let の並びと return だけのブロックに空行があれば止める" $'func a() -> Int {\n    let b = 1\n    let c = 2\n    let d = 3\n\n    return b + c + d\n}' "Case.swift:6: L7: 1 行の let の並びと最後の return だけのブロックには、空行を入れない"
layout_case 0 "L7: 代入と呼び出しは、同じ段落として続けて書ける" $'func a() {\n    let b = 1\n\n    c = b\n    d()\n    e = b\n    f()\n\n    return\n}'
layout_case 0 "L7: super の呼び出しは、短いブロックでも空行で分ける" $'final class Case: Base {\n    override func a() {\n        super.a()\n\n        b()\n    }\n}'
layout_case 0 "L7: init の代入の間の空行は見ない" $'struct Case {\n    init() {\n        _a = State(initialValue: 1)\n\n        b = 2\n        c = 3\n        d = 4\n    }\n}'
layout_case 0 "L7: 画面を組み立てるブロックと #Preview は見ない" $'struct Case {}\n\nprivate extension Case {\n    var title: some View {\n        Text("a")\n\n        Text("b")\n    }\n}\n\n#Preview {\n    Text("a")\n\n    Text("b")\n}'
layout_case 0 "L7: 1 行のクロージャと 1 行の case は見ない" $'func a() -> Int {\n    let b = c.map { $0 + 1 }\n    return b.count\n}'

layout_case 2 "L8: 61 行の関数は止める" "$(long_function 61)" "Case.swift:2: L8: 1 つの関数は 60 行までにする"
layout_case 0 "L8: 60 行ちょうどの関数は通る" "$(long_function 60)"

hook_case swift-layout-check 0 "Tests のフォルダの下は見ない" "$work/Tests/Case.swift" $'struct Case {\n    func a() {}\n}'
hook_case swift-layout-check 0 ".claude の下は見ない" "$app/.claude/Case.swift" $'struct Case {\n    func a() {}\n}'

base="$work/base"
mkdir -p "$base/Sources"
git -C "$base" init -q
printf 'struct Case {\n    func a() {}\n}\n' >"$base/Sources/Case.swift"
out=$(bash "$hooks" swift-layout-check "$base/Sources/Case.swift" </dev/null 2>&1)
match "基準線が無ければ、今ある外れを NG にする" "$?:$(grep -c '^NG ' <<<"$out")" "2:1"
bash "$hooks" swift-layout-check --write-baseline "$base/Sources/Case.swift" </dev/null >/dev/null 2>&1
check "--write-baseline は、今ある外れを基準線に書く" grep -q 'Sources/Case.swift: L3' "$base/.claude/swift-layout-baseline.txt"
out=$(bash "$hooks" swift-layout-check "$base/Sources/Case.swift" </dev/null 2>&1)
match "基準線にある外れは通す" "$?" "0"
printf 'struct Case {}\n' >"$base/Sources/Case.swift"
out=$(bash "$hooks" swift-layout-check "$base/Sources/Case.swift" </dev/null 2>&1)
match "直った外れが基準線に残っていたら NG にする" "$?:$(grep -c '行を消す' <<<"$out")" "2:1"

# <ラベル> <直す前の中身> <直した後に含む文> で、--fix が外れを無くし、文を含むかを見る
fix_case() {
    local label=$1 text=$2 want=$3 out
    printf '%s\n' "$text" >"$base/Sources/Case.swift"
    bash "$hooks" swift-layout-check --fix "$base/Sources/Case.swift" </dev/null >/dev/null 2>&1
    out=$(bash "$hooks" swift-layout-check "$base/Sources/Case.swift" </dev/null 2>&1)
    match "--fix: ${label}（外れが無くなる）" "$?" "0"
    check "--fix: ${label}（直した形）" bash -c '[[ $(<"$1") == *"$2"* ]]' _ "$base/Sources/Case.swift" "$want"
}

rm -f "$base/.claude/swift-layout-baseline.txt"
fix_case "要らない空行を消す" $'enum Case {\n    static func a() {\n        b()\n\n        c()\n    }\n}' $'        b()\n        c()'
fix_case "要る空行を足す" $'enum Case {\n    static func a() {\n        let b = 1\n        c(b)\n        d()\n        e()\n    }\n}' $'        let b = 1\n\n        c(b)'
fix_case "型の宣言と関数の混ざった extension を分ける" $'struct Case {}\n\nextension Case {\n    struct Row {}\n\n    func a() {}\n}' $'extension Case {\n    func a() {}\n}'
fix_case "同じ役割の extension をまとめる" $'struct Case {}\n\nextension Case {\n    func a() {}\n}\n\nextension Case {\n    func b() {}\n}' $'    func a() {}\n\n    func b() {}'
fix_case "extension を区画の順に並べ替える" $'struct Case {}\n\nprivate extension Case {\n    func a() {}\n}\n\nextension Case {\n    func b() {}\n}' $'extension Case {\n    func b() {}\n}\n\nprivate extension Case {'
fix_case "部品と処理を分ける" $'struct Case {}\n\nprivate extension Case {\n    var count: Int {\n        1\n    }\n\n    var title: some View {\n        Text("a")\n    }\n}' $'        Text("a")\n    }\n}\n\nprivate extension Case {\n    var count: Int {'
fix_case "本体の関数を extension に出し、public を extension に上げる" $'public struct Case {\n    public let a: Int\n\n    public func b() {}\n}' $'public extension Case {\n    func b() {}\n}'
fix_case "internal の型の public は、無印の extension に出す" $'struct Case {\n    let a: Int\n\n    public func b() {}\n}' $'\nextension Case {\n    func b() {}\n}'
fix_case "package の型の public は、package extension に出す" $'package struct Case {\n    package let a: Int\n\n    public func b() {}\n}' $'package extension Case {\n    func b() {}\n}'
fix_case "public の型の package は、修飾子を残して public extension に出す" $'public struct Case {\n    public let a: Int\n\n    package func b() {}\n}' $'public extension Case {\n    package func b() {}\n}'
fix_case "入れ子の型から出す時に、親の型の名前を補う" $'struct Case {}\n\nextension Case {\n    enum Kind {\n        case a\n    }\n\n    struct Row {\n        let kind: Kind\n\n        func same(_ other: Kind) -> Bool {\n            kind == other\n        }\n    }\n}' $'func same(_ other: Case.Kind) -> Bool {'
fix_case "@available を、出した先の extension に付ける" $'@available(iOS 26.0, *)\nstruct Case {\n    let a: Int\n\n    func b() {}\n}' $'@available(iOS 26.0, *)\nextension Case {'
fix_case "適合の extension の中の型は分けない" $'struct Case {}\n\nextension Case: Codable {\n    enum CodingKeys: String, CodingKey {\n        case a\n    }\n\n    func encode(to encoder: any Encoder) throws {}\n}' $'    enum CodingKeys: String, CodingKey {\n        case a\n    }\n\n    func encode'

finish
