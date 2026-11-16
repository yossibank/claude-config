#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"
source "$(dirname "$0")/../support/hook_fixtures.sh"

style_case() {
    local expect=$1 label=$2 text=$3 want=${4:-}
    [[ $expect != 2 || -n $want ]] || want="Kotlin の決まり（rules/kotlin-*.md）に合わない箇所がある"
    hook_case kotlin-style-check "$expect" "$label" "$work/Case.kt" "$text" "$want"
}

style_case 2 "1 行の val と return の間に空行があれば止める" $'fun a(): Int {\n    val b = 1\n    val c = 2\n\n    return b + c\n}' "Case.kt:5: 1 行の val の並び"
style_case 0 "1 行の val と return を続けて書けば通る" $'fun a(): Int {\n    val b = 1\n    val c = 2\n    val d = 3\n    return b + c + d\n}'
style_case 0 "return で始まる名前への代入は return と数えない" $'fun a() {\n    val b = 1\n\n    returnValue = b\n}'

style_case 2 "if で抜けた後に空行が無ければ止める" $'fun a() {\n    if (b) {\n        return\n    }\n    c()\n}' "Case.kt:5: 早く抜ける行"
style_case 0 "if で抜けた後に空行があれば通る" $'fun a() {\n    if (b) {\n        return\n    }\n\n    c()\n}'
style_case 2 "長いブロックで ?: return の後に空行が無ければ止める" $'fun a() {\n    val b = c ?: return\n    d(b)\n    e()\n    f()\n}' "Case.kt:3: 早く抜ける行"
style_case 0 "?: return の val が続き、処理の前に空行があれば通る" $'fun a() {\n    val b = c ?: return\n    val d = e ?: return\n\n    f(b, d)\n    g()\n}'
style_case 0 "?: return の val の後に最後の return が続く長いブロックは通る" $'fun a(): Int {\n    val p = 1\n    val q = 2\n    val b = c ?: return 0\n    return p + q + b\n}'
style_case 0 "1 行の文が 3 つまでのブロックの ?: return は見ない" $'fun a() {\n    val b = c ?: return\n    d(b)\n}'

style_case 2 "同じ Composable の 1 行の呼び出しの間に空行があれば止める" $'fun A() {\n    Row {\n        Chip("a")\n\n        Chip("b")\n    }\n}' "Case.kt:5: 同じ Composable の 1 行"
style_case 0 "同じ Composable の 1 行の呼び出しを続けて書けば通る" $'fun A() {\n    Row {\n        Chip("a")\n        Chip("b")\n    }\n}'
style_case 2 "Composable が変わる並びに空行が無ければ止める" $'fun A() {\n    Row {\n        Title()\n        Spacer(modifier = Modifier.weight(1f))\n    }\n}' "Case.kt:4: Composable が変わる並び"
style_case 2 "引数を折り返した並びでも見る" $'fun A() {\n    Column(\n        modifier = Modifier,\n    ) {\n        Title()\n        Days()\n    }\n}' "Case.kt:6: Composable が変わる並び"
style_case 0 "Composable が変わる並びに空行があれば通る" $'fun A() {\n    Row {\n        Title()\n\n        Days()\n    }\n}'
style_case 0 "val を含む並びは見ない" $'fun A() {\n    Column {\n        val a = 1\n        Title()\n    }\n}'

style_case 0 "文字列とコメントの中の return は見ない" $'fun a(): String {\n    val b = "x ?: return"\n\n    // return\n    c()\n    return b\n}'
style_case 0 "テンプレートの中の入れ子の文字列も、文字列として見ない" $'fun a(): String {\n    val b = "${c("{")}"\n    return b\n}'
style_case 0 "文字の中の引用符で、文字列が始まったと見ない" $'fun a(): Char {\n    val b = \'"\'\n    return b\n}'

finish
