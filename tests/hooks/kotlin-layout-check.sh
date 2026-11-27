#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"

printf 'fun a() = 1\n' >"$work/Build.kt"
check "kotlin-layout を組める" bash "$root/dotclaude/hooks/run.sh" kotlin-layout-check "$work/Build.kt"

source "$(dirname "$0")/../support/hook_fixtures.sh"

layout_case() {
    local expect=$1 label=$2 text=$3 want=${4:-}
    hook_case kotlin-layout-check "$expect" "$label" "$work/Case.kt" "$text" "$want"
}

long_function() {
    local out=$'fun a() {\n' i
    for ((i = 0; i < $1 - 2; i++)); do out+=$'    b()\n'; done
    printf '%s' "${out}}"
}

when_table() {
    local out=$'fun a(i: Int): Int = when (i) {\n' i
    for ((i = 0; i < $1; i++)); do out+="    ${i} -> ${i}"$'\n'; done
    printf '%s' "${out}    else -> 0"$'\n}'
}

layout_case 2 "K1: private の値の後に公開の関数を置けば止める" $'private val a = 1\n\nfun b() = a' "Case.kt:3: K1: ファイルの区画の順が違う。「公開と internal の値・拡張・関数」は「private の値」より前に置く"
layout_case 2 "K1: 公開の const をファイルの型の後に置けば止める" $'class Case\n\nconst val LIMIT = 1' "Case.kt:3: K1: ファイルの区画の順が違う。「公開の const」は「ファイルの名前の型」より前に置く"
layout_case 2 "K1: @Preview の後に宣言を置けば止める" $'@Preview\n@Composable\nprivate fun CasePreview() {}\n\nfun a() = 1' "Case.kt:5: K1: ファイルの区画の順が違う。「公開と internal の値・拡張・関数」は「@Preview」より前に置く"
layout_case 0 "K1: const・型・ほかの型・公開・private・private の値・@Preview の順なら通る" $'const val LIMIT = 1\n\nclass Case\n\nclass Other\n\nfun Case.a() = 1\n\nprivate fun b() = 2\n\nprivate val c = 3\n\n@Preview\n@Composable\nprivate fun CasePreview() {}'

layout_case 2 "K2: 拡張だけのファイルで、internal の後に公開を置けば止める" $'internal fun Case.a() = 1\n\nfun Case.b() = 2' "Case.kt:3: K2: 拡張だけのファイルは、公開・internal・private の順に並べる"
layout_case 0 "K2: 公開・internal・private の順なら通る" $'fun Case.a() = 1\n\ninternal fun Case.b() = 2\n\nprivate fun Case.c() = 3'

layout_case 2 "K3: 関数の後に保存プロパティを置けば止める" $'class Case {\n    fun a() = 1\n\n    val b = 2\n}' "Case.kt:4: K3: クラスの中の順が違う。「保存プロパティと要求」は「公開の関数と計算プロパティ」より前に置く"
layout_case 2 "K3: 入れ子の型の後に保存プロパティを置けば止める" $'class Case {\n    class Row\n\n    val a = 1\n}' "Case.kt:4: K3: クラスの中の順が違う。「保存プロパティと要求」は「入れ子の型」より前に置く"
layout_case 2 "K3: private の関数の後に公開の関数を置けば止める" $'class Case {\n    private fun a() = 1\n\n    fun b() = 2\n}' "Case.kt:4: K3: クラスの中の順が違う。「公開の関数と計算プロパティ」は「private の関数と計算プロパティ」より前に置く"
layout_case 2 "K3: 画面のモデルの値の順が違えば止める" $'class Case {\n    val output = 1\n    val state = 2\n}' "Case.kt:3: K3: 画面のモデルの値は、state・input・output・dependencies の順に並べる"
layout_case 2 "K3: まとまりの型の順が違えば止める" $'class Case {\n    class Output\n\n    class State\n}' "Case.kt:4: K3: まとまりの型は、State・Input・Output・Dependencies の順に並べる"
layout_case 0 "K3: 保存・init・入れ子の型・override・公開・internal・private・companion の順なら通る" $'class Case(private val x: Int) : Base() {\n    val state = 1\n    val input = 2\n\n    private val dependencies = 3\n\n    init {\n        start()\n    }\n\n    class State\n\n    override fun a() = 1\n\n    val total: Int\n        get() = x\n\n    val doubled by lazy { x * 2 }\n\n    fun b() = 2\n\n    internal fun c() = 3\n\n    private fun d() = 4\n\n    companion object {\n        const val LIMIT = 1\n    }\n}'

layout_case 2 "K4: 入れ子が 3 段になれば止める" $'class Case {\n    class A {\n        class B {\n            class C\n        }\n    }\n}' "Case.kt:4: K4: 入れ子の型は 2 段までにする"
layout_case 0 "K4: 入れ子が 2 段ちょうどなら通る" $'class Case {\n    class A {\n        class B\n    }\n}'

layout_case 2 "K6: 複数行の宣言の後に空行が無ければ止める" $'class Case {\n    val a = listOf(\n        1,\n    )\n    val b = 2\n}' "Case.kt:5: K6: 複数行の宣言の前後には、空行を入れる"
layout_case 2 "K6: 1 行の宣言を複数行の宣言の後に置けば止める" $'class Case {\n    val a = listOf(\n        1,\n    )\n\n    val b = 2\n}' "Case.kt:6: K6: 1 行の宣言は、同じまとまりの複数行の宣言より前に置く"
layout_case 2 "K6: 同じまとまりの 1 行の宣言の間に空行があれば止める" $'class Case {\n    val a = 1\n\n    val b = 2\n}' "Case.kt:4: K6: 同じまとまりの 1 行の宣言の間に、空行を入れない"
layout_case 2 "K6: internal set の付いた 2 行の宣言は、複数行に数える" $'class Case {\n    var a by mutableStateOf(0)\n        internal set\n    var b by mutableStateOf(1)\n        internal set\n}' "Case.kt:4: K6: 複数行の宣言の前後には、空行を入れる"
layout_case 0 "K6: まとまりが変わる所の空行と、1 行を先にした並びは通る" $'class Case {\n    val a = 1\n    val b = 2\n\n    val c = listOf(\n        3,\n    )\n\n    private val d = 4\n}'

layout_case 2 "K7: 1 行の文が 3 つまでのブロックに空行があれば止める" $'fun a() {\n    b()\n\n    c()\n}' "Case.kt:4: K7: 1 行の文が 3 つまでのブロックには、空行を入れない"
layout_case 2 "K7: 同じ段落の 1 行の文の間に空行があれば止める" $'fun a() {\n    b()\n    c()\n\n    d()\n    e()\n}' "Case.kt:5: K7: 同じ段落の 1 行の文の間に、空行を入れない"
layout_case 2 "K7: 準備と実行の間に空行が無ければ止める" $'fun a() {\n    val b = 1\n    c(b)\n    d()\n    e()\n}' "Case.kt:3: K7: 段落（準備・実行・出口）が変わる所には、空行を入れる"
layout_case 2 "K7: 複数行の文の前に空行が無ければ止める" $'fun a() {\n    b()\n    if (c) {\n        d()\n    }\n}' "Case.kt:3: K7: 複数行の文の前後には、空行を入れる"
layout_case 2 "K7: val の並びと return だけのブロックに空行があれば止める" $'fun a(): Int {\n    val b = 1\n    val c = 2\n    val d = 3\n\n    return b + c + d\n}' "Case.kt:6: K7: 1 行の val の並びと最後の return だけのブロックには、空行を入れない"
layout_case 2 "K7: 値を返すラムダの最後の式の前に空行が無ければ止める" $'fun a(items: List<Int>) = items.map { item ->\n    val b = item + 1\n    b * 2\n}' "Case.kt:3: K7: 値を返すブロックの最後の式の前には、空行を入れる"
layout_case 2 "K7: 値を返す when の分岐の最後の式の前に空行が無ければ止める" $'fun a(c: Boolean): Int = when (c) {\n    true -> {\n        val b = 1\n        b + 1\n    }\n\n    false -> 0\n}' "Case.kt:4: K7: 値を返すブロックの最後の式の前には、空行を入れる"
layout_case 0 "K7: 値を返すブロックは、最後の式の前に空行を入れれば通る" $'fun a(items: List<Int>) = items.map { item ->\n    val b = item + 1\n\n    b * 2\n}'
layout_case 0 "K7: 代入と呼び出しは、同じ段落として続けて書ける" $'fun a() {\n    val b = 1\n\n    c = b\n    d()\n    e = b\n    f()\n\n    return\n}'
layout_case 0 "K7: super の呼び出しは、短いブロックでも空行で分ける" $'class Case : Base() {\n    override fun a() {\n        super.a()\n\n        b()\n    }\n}'
layout_case 0 "K7: init の代入の間の空行は見ない" $'class Case {\n    init {\n        a = 1\n\n        b = 2\n        c = 3\n        d = 4\n    }\n}'
layout_case 0 "K7: 画面を組み立てるラムダは見ない" $'@Composable\nfun Case() {\n    Column {\n        Text("a")\n\n        Text("b")\n    }\n}'
layout_case 0 "K7: 値を返すか分からないラムダの最後の式の前は見ない" $'fun a() = transaction {\n    val b = 1\n\n    b + 1\n}'

layout_case 2 "K8: 61 行の関数は止める" "$(long_function 61)" "Case.kt:1: K8: 1 つの関数は 60 行までにする"
layout_case 0 "K8: 60 行ちょうどの関数は通る" "$(long_function 60)"
layout_case 0 "K8: 全部の分岐が 1 行の when の表は、長くても通る" "$(when_table 70)"

layout_case 2 "K9: 組み立ての後に効果を置けば止める" $'@Composable\nfun Case() {\n    Text("a")\n\n    LaunchedEffect(Unit) {\n        load()\n    }\n}' "Case.kt:5: K9: Composable の本体は、持つ val・派生の val・効果・組み立ての順に並べる。「効果」は「組み立て」より前に置く"
layout_case 2 "K9: 派生の val の後に remember の val を置けば止める" $'@Composable\nfun Case(a: Int) {\n    val b = a + 1\n    val c = remember { 1 }\n\n    Text("$b$c")\n}' "Case.kt:4: K9: Composable の本体は、持つ val・派生の val・効果・組み立ての順に並べる。「持つ val」は「派生の val」より前に置く"
layout_case 0 "K9: 持つ val・派生の val・効果・組み立ての順なら通る" $'@Composable\nfun Case(a: Int) {\n    val c = remember { 1 }\n    val b = a + c\n\n    LaunchedEffect(Unit) {\n        load()\n    }\n\n    Text("$b")\n}'

hook_case kotlin-layout-check 0 "test のフォルダの下は見ない" "$work/src/test/Case.kt" $'class Case {\n    fun a() = 1\n\n    val b = 2\n}'
hook_case kotlin-layout-check 0 ".claude の下は見ない" "$app/.claude/Case.kt" $'class Case {\n    fun a() = 1\n\n    val b = 2\n}'

base="$work/base"
mkdir -p "$base/src"
git -C "$base" init -q
printf 'class Case {\n    fun a() = 1\n\n    val b = 2\n}\n' >"$base/src/Case.kt"
out=$(bash "$hooks" kotlin-layout-check "$base/src/Case.kt" </dev/null 2>&1)
match "基準線が無ければ、今ある外れを NG にする" "$?:$(grep -c '^NG ' <<<"$out")" "2:1"
bash "$hooks" kotlin-layout-check --write-baseline "$base/src/Case.kt" </dev/null >/dev/null 2>&1
check "--write-baseline は、今ある外れを基準線に書く" grep -q 'src/Case.kt: K3' "$base/.claude/kotlin-layout-baseline.txt"
out=$(bash "$hooks" kotlin-layout-check "$base/src/Case.kt" </dev/null 2>&1)
match "基準線にある外れは通す" "$?" "0"
printf 'class Case {\n    val b = 2\n}\n' >"$base/src/Case.kt"
out=$(bash "$hooks" kotlin-layout-check "$base/src/Case.kt" </dev/null 2>&1)
match "直った外れが基準線に残っていたら NG にする" "$?:$(grep -c '行を消す' <<<"$out")" "2:1"

fix_case() {
    local label=$1 text=$2 want=$3 out
    printf '%s\n' "$text" >"$base/src/Case.kt"
    bash "$hooks" kotlin-layout-check --fix "$base/src/Case.kt" </dev/null >/dev/null 2>&1
    out=$(bash "$hooks" kotlin-layout-check "$base/src/Case.kt" </dev/null 2>&1)
    match "--fix: ${label}（外れが無くなる）" "$?" "0"
    check "--fix: ${label}（直した形）" bash -c '[[ $(<"$1") == *"$2"* ]]' _ "$base/src/Case.kt" "$want"
}

rm -f "$base/.claude/kotlin-layout-baseline.txt"
fix_case "要らない空行を消す" $'fun a() {\n    b()\n\n    c()\n}' $'    b()\n    c()'
fix_case "要る空行を足す" $'fun a() {\n    val b = 1\n    c(b)\n    d()\n    e()\n}' $'    val b = 1\n\n    c(b)'
fix_case "値を返すブロックの最後の式の前に空行を足す" $'fun a(items: List<Int>) = items.map { item ->\n    val b = item + 1\n    b * 2\n}' $'    val b = item + 1\n\n    b * 2'
fix_case "同じまとまりの宣言の間の空行を消す" $'class Case {\n    val a = 1\n\n    val b = 2\n}' $'    val a = 1\n    val b = 2'
fix_case "ファイルの区画を並べ替え、コメントも一緒に動かす" $'private val a = 1\n\n// 説明\nfun b() = a' $'// 説明\nfun b() = a\n\nprivate val a = 1'
fix_case "クラスの中を並べ替える" $'class Case {\n    private fun a() = 1\n\n    class Row\n\n    fun b() = 2\n}' $'    class Row\n\n    fun b() = 2\n\n    private fun a() = 1'

printf 'class Case {\n    init {\n        a()\n    }\n\n    val b = 1\n}\n' >"$base/src/Case.kt"
bash "$hooks" kotlin-layout-check --fix "$base/src/Case.kt" </dev/null >/dev/null 2>&1
check "--fix: 値を作る順が変わる並べ替えはしない" grep -q $'^    init {' <(head -2 "$base/src/Case.kt")

printf 'class Case {\r\n    fun a() {\r\n        b()\r\n    }\r\n    fun c() {\r\n        d()\r\n    }\r\n}\r\n' >"$base/src/Case.kt"
bash "$hooks" kotlin-layout-check --fix "$base/src/Case.kt" </dev/null >/dev/null 2>&1
check "--fix: CRLF のファイルは、CRLF のまま直す" bash -c '! grep -q $'"'"'[^\r]$'"'"' "$1"' _ "$base/src/Case.kt"
check "--fix: CRLF のファイルにも空行を足す" grep -qx $'\r' "$base/src/Case.kt"

layout_case 0 "K3: interface の本体の無い要求は、保存プロパティと同じ先頭に置ける" $'interface Case {\n    val icon: Int\n\n    fun validate()\n\n    fun total(): Int = icon + 1\n}'
layout_case 2 "K3: interface の要求を、既定の実装の後に置けば止める" $'interface Case {\n    fun total(): Int = icon + 1\n\n    val icon: Int\n}' "K3: クラスの中の順が違う。「保存プロパティと要求」は「公開の関数と計算プロパティ」より前に置く"

finish
