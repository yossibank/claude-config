#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hook_fixtures.sh"

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

style_case 2 "1 行の let と return の間に空行があれば止める" $'var a: Int {\n    let b = 1\n    let c = 2\n\n    return b + c\n}' "Case.swift:5: 1 行の let の並び"
style_case 0 "return で始まる名前への代入は return と数えない" $'func a() {\n    let b = 1\n\n    returnValue = b\n}'
style_case 0 "1 行の let と return を続けて書けば通る" $'var a: Int {\n    let b = 1\n    let c = 2\n    let d = 3\n    return b + c + d\n}'

style_case 2 "同じ型の 1 行のビューの間に空行があれば止める" $'var a: some View {\n    VStack {\n        Text("a")\n\n        Text("b")\n    }\n}' "Case.swift:5: 同じ型の 1 行のビュー"
style_case 0 "同じ型の 1 行のビューを続けて書けば通る" $'var a: some View {\n    HStack {\n        Text("a")\n        Text("b")\n    }\n}'
style_case 2 "型が変わるビューの間に空行が無ければ止める" $'var a: some View {\n    HStack {\n        Text("a")\n        Spacer()\n    }\n}' "Case.swift:4: 型が変わるビュー"
style_case 2 "複数行のビューを含む並びに空行が無ければ止める" $'var a: some View {\n    VStack {\n        Text("a")\n            .bold()\n        Text("b")\n    }\n}' "Case.swift:5: 型が変わるビュー"
style_case 0 "型が変わるビューの間に空行があれば通る" $'var a: some View {\n    HStack {\n        Text("a")\n\n        Spacer()\n    }\n}'
style_case 0 "let を含むビューの並びは見ない" $'#Preview {\n    let a = 1\n    Text("a")\n}'

style_case 0 "補間の中の入れ子の文字列も、文字列として見ない" 'let a = "\(c ? "x && y ? 1 : 2" : "z")"'
style_case 2 "補間のある文字列の後ろの三項演算子は見る" $'let a = "\\(b)"; let c = d && e ? 1 : 2' "Case.swift:1: 条件に && か ||"

finish
