#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"
source "$(dirname "$0")/../support/hook_fixtures.sh"

design_case() {
    local expect=$1 label=$2 path=$3 text=$4 want=${5:-}
    [[ $expect != 2 || -n $want ]] || want="設計の決まり（rules/code-design.md）に合わない箇所がある"
    hook_case code-design-check "$expect" "$label" "$path" "$text" "$want"
}

# <数> <行> を、数だけ並べる
repeat() {
    local count=$1 line=$2 out="" i
    for ((i = 0; i < count; i++)); do out+="${line}"$'\n'; done
    printf '%s' "$out"
}

# <保存プロパティの数> <Bool の数> <didSet の数> の @Observable のクラス
model() {
    local out=$'@Observable\nfinal class Case {\n' i
    for ((i = 0; i < $1; i++)); do out+="    var value${i}: Int = 0"$'\n'; done
    for ((i = 0; i < $2; i++)); do out+="    private(set) var isFlag${i} = false"$'\n'; done
    for ((i = 0; i < $3; i++)); do out+="    var watched${i}: Int = 0 {"$'\n        didSet {}\n    }\n'; done
    out+=$'\n    var total: Int {\n        1\n    }\n}'
    printf '%s' "$out"
}

# <数> の mutableStateOf を持つクラス
states() {
    local out=$'class Case {\n' i
    for ((i = 0; i < $1; i++)); do out+="    var value${i} by mutableStateOf(0)"$'\n'; done
    printf '%s' "${out}}"
}

# <型の名前> <行の数> <変数の頭> で、形が同じで名前だけ違う中身を作る
body() {
    local out="struct $1 {"$'\n' i
    for ((i = 1; i < $2; i++)); do out+="    let $3${i} = make$3(${i})"$'\n'; done
    printf '%s' "${out}}"
}

# <型の名前> <変数の頭> の、保存プロパティと init だけを持つ Swift の struct
record() {
    local out="public struct $1: Sendable {"$'\n' names=(id title note amount date) i
    for i in "${names[@]}"; do out+="    public let $2${i}: String"$'\n'; done
    out+=$'\n    public init(\n'
    for i in "${names[@]}"; do out+="        $2${i}: String,"$'\n'; done
    out+=$'        flag: Bool = false\n    ) {\n'
    for i in "${names[@]}"; do out+="        self.$2${i} = $2${i}"$'\n'; done
    printf '%s' "${out}    }"$'\n}'
}

# <型の名前> <変数の頭> の、同じ並びの引数を持つ Kotlin の data class
data_class() {
    local out="data class $1(" names=(id title note amount date) i
    out+=$'\n'
    for i in "${names[@]}"; do out+="    val $2${i}: String,"$'\n'; done
    printf '%s' "${out}    var flag: Boolean = false"$'\n)'
}

# <型の名前> <変数の頭> の、保存プロパティの間に同じ処理の本体がある struct
mixed() {
    local out="struct $1 {"$'\n    let '"$2"$'Id: String\n    func run() {\n' i
    for ((i = 1; i < 22; i++)); do out+="        let $2${i} = make$2(${i})"$'\n'; done
    printf '%s' "${out}    }"$'\n    let '"$2"$'Name: String\n}'
}

# <型の名前> <表の名前> の、注釈の付いた列と、本体の無い関数を持つ Kotlin の Room の宣言
room() {
    local out=$'@Entity(\n    tableName = "'"$2"$'",\n    foreignKeys = [\n        ForeignKey(\n            entity = IconRecord::class,\n            parentColumns = ["id"],\n            childColumns = ["icon_id"],\n        ),\n    ],\n)\n'
    out+="data class $1("$'\n    @PrimaryKey val id: String,\n    @ColumnInfo(name = "icon_id") val iconId: String,\n    @ColumnInfo(name = "sort_order") val sortOrder: Int,\n)\n\n@Dao\ninterface '"$1"$'Dao {\n'
    out+=$'    @Query("SELECT * FROM x WHERE id = :id")\n    suspend fun find(id: String): Item?\n\n'
    out+=$'    @Query("SELECT * FROM x ORDER BY id")\n    suspend fun all(): List<Item>\n\n'
    out+=$'    @Query("DELETE FROM x")\n    suspend fun deleteAll()\n\n'
    out+=$'    @Query("SELECT COUNT(*) FROM x")\n    suspend fun count(): Int\n\n'
    out+=$'    @Query("DELETE FROM x WHERE id = :id")\n    suspend fun delete(id: String)\n'
    printf '%s' "${out}}"
}

# <プロトコルの名前> <要求の頭> の、関数の要求だけを持つ Swift の protocol
requirements() {
    local out="protocol $1 {"$'\n' i
    local params=("" "a: Int" "a: Int, b: Int" "a: Int, b: Int, c: Int") effects=("" " throws" " async" " async throws" " mutating")
    for ((i = 0; i < 20; i++)); do out+="    func $2${i}(${params[i % 4]})${effects[i % 5]} -> String"$'\n'; done
    printf '%s' "${out}}"
}

swift="$work/Case.swift"
kotlin="$work/Case.kt"

# --- ファイルの長さ ---
design_case 0 "400 行ちょうどの Swift は通る" "$swift" "struct Case {"$'\n'"$(repeat 398 '    // a')"$'\n}'
design_case 2 "401 行の Swift は止める" "$swift" "struct Case {"$'\n'"$(repeat 399 '    // a')"$'\n}' "Case.swift:401: 1 つのファイルは 400 行まで"
design_case 0 "400 行ちょうどの Kotlin は通る" "$kotlin" "class Case {"$'\n'"$(repeat 398 '    // a')"$'\n}'
design_case 2 "401 行の Kotlin は止める" "$kotlin" "class Case {"$'\n'"$(repeat 399 '    // a')"$'\n}' "Case.kt:401: 1 つのファイルは 400 行まで"
design_case 2 "テストのファイルも長さは見る" "$work/Tests/CaseTests.swift" "struct CaseTests {"$'\n'"$(repeat 399 '    // a')"$'\n}' "400 行まで"

# --- ファイルの名前と型 ---
design_case 0 "ファイルと同じ名前の型があれば通る" "$swift" 'struct Case {}'
design_case 2 "ファイルと同じ名前の型が無ければ止める" "$swift" 'struct Other {}' "Case.swift:1: ファイルの名前は、中の型の名前にする: Case"
design_case 2 "拡張だけのファイルに + が無ければ止める" "$swift" 'extension Other {}' "ファイルの名前は、中の型の名前にする"
design_case 0 "View の拡張だけのファイルは、画面の名前で通る" "$work/CaseNotice.swift" 'extension View {}'
design_case 0 "拡張のファイルの頭が拡張する型なら通る" "$work/Case+Role.swift" 'extension Case {}'
design_case 2 "拡張のファイルの頭が拡張する型と違えば止める" "$work/Case+Role.swift" 'extension Other {}' "Case+Role.swift:1: 拡張のファイルの頭は、拡張する型の名前にする: Case"
design_case 0 "入れ子の型の拡張は . を抜いた名前で通る" "$work/WalletKind+Title.swift" 'extension Wallet.Kind {}'
design_case 0 "入れ子の型の拡張は、親の型の名前でも通る" "$work/Wallet+Title.swift" 'extension Wallet.Kind {}'
design_case 2 "入れ子の型の拡張で親を省けば止める" "$work/WalletRole+Balance.swift" 'extension Wallet.Kind.Role {}' "拡張のファイルの頭は、拡張する型の名前にする: WalletRole"
design_case 0 "配列の拡張は Array の名前で通る" "$work/Array+Detail.swift" 'extension [String?] {}'
design_case 0 "テストのファイルの名前は見ない" "$work/Tests/Other.swift" 'struct Sample {}'

# --- 1 つのファイルに置く型 ---
design_case 2 "名前の頭が違う型を並べれば止める" "$swift" $'struct Case {}\n\nstruct Helper {}' "Case.swift:3: private でない型の名前は、ファイルの名前 Case で始める: Helper"
design_case 0 "private な型は並べて通る" "$swift" $'struct Case {}\n\nprivate struct Helper {}'
design_case 0 "ファイルの名前で始まる型は並べて通る" "$swift" $'struct Case {}\n\nstruct CaseRow {}'
design_case 0 "拡張のファイルは、役割の名前で始まる型も通る" "$work/Case+Role.swift" $'extension Case {}\n\nstruct RoleValue {}'
design_case 0 "入れ子の型は見ない" "$swift" $'struct Case {\n    struct Helper {}\n}'
design_case 2 "Kotlin で名前の語が違う型を並べれば止める" "$kotlin" $'class Case\n\nclass Helper' "Case.kt:3: private でない型の名前は、ファイルの名前の語で始める: Helper"
design_case 0 "Kotlin でファイルの名前の語で始まる型は通る" "$work/AppDatabaseBudget.kt" $'class AppDatabaseBudget\n\nclass BudgetWriteException'
design_case 0 "Kotlin の private な型は並べて通る" "$kotlin" $'class Case\n\nprivate class Helper'

# --- フォルダの中の頭が同じファイル ---
heads="$work/heads"
mkdir -p "$heads"
for i in A B C D E F G H I J K L M N O P Q R S; do echo "struct Head${i}x {}" >"$heads/Head${i}x.swift"; done
echo 'struct MigrationV001 {}' >"$heads/HeadV001.swift"
design_case 0 "頭が同じファイルが 20 本ちょうどなら通る" "$heads/HeadMain.swift" 'struct HeadMain {}'
echo 'struct HeadLast {}' >"$heads/HeadLast.swift"
design_case 2 "頭が同じファイルが 21 本なら止める" "$heads/HeadMain.swift" 'struct HeadMain {}' "頭が Head のファイルが 21 本ある"
rm "$heads/HeadLast.swift"
echo 'struct OtherLast {}' >"$heads/OtherLast.swift"
design_case 0 "頭が違うファイルは別に数える" "$heads/HeadMain.swift" 'struct HeadMain {}'

# --- モデルの状態 ---
design_case 0 "保存プロパティが 12 個ちょうどなら通る" "$swift" "$(model 12 0 0)"
design_case 2 "保存プロパティが 13 個なら止める" "$swift" "$(model 13 0 0)" "Case.swift:15: Case の保存プロパティの var は 12 個まで"
design_case 0 "Bool の保存プロパティが 3 個ちょうどなら通る" "$swift" "$(model 0 3 0)"
design_case 2 "Bool の保存プロパティが 4 個なら止める" "$swift" "$(model 0 4 0)" "Case の Bool の保存プロパティは 3 個まで"
design_case 0 "didSet が 2 個ちょうどなら通る" "$swift" "$(model 0 0 2)"
design_case 2 "didSet が 3 個なら止める" "$swift" "$(model 0 0 3)" "Case の didSet と willSet は 2 個まで"
design_case 0 "@Observable でない型の保存プロパティは数えない" "$swift" "$(model 13 0 0 | tail -n +2)"
design_case 0 "mutableStateOf が 12 個ちょうどなら通る" "$kotlin" "$(states 12)"
design_case 2 "mutableStateOf が 13 個なら止める" "$kotlin" "$(states 13)" "Case.kt:14: Case の mutableStateOf の var は 12 個まで"

# --- 今の時刻の既定値 ---
design_case 2 "引数の既定値に Date() を書けば止める" "$swift" $'struct Case {\n    func save(at now: Date = Date()) {}\n}' "Case.swift:2: 今の時刻を引数やプロパティの既定値にしない"
design_case 2 "引数の既定値に .now を書いても止める" "$swift" $'struct Case {\n    func save(at now: Date = .now) {}\n}' "今の時刻を"
design_case 0 "時刻を必須の引数で受ければ通る" "$swift" $'struct Case {\n    func save(at now: Date) {}\n}'
design_case 0 "文字列とコメントの中の Date() は見ない" "$swift" $'struct Case {\n    let a = "now: Date = Date()" // b: Date = Date()\n}'
design_case 2 "Kotlin の既定値に Instant.now() を書けば止める" "$kotlin" $'class Case {\n    fun save(at: Instant = Instant.now()) {}\n}' "Case.kt:2: 今の時刻を"
design_case 0 "Kotlin で時刻を必須の引数で受ければ通る" "$kotlin" $'class Case {\n    fun save(at: Instant) {}\n}'

# --- 別のファイルと同じ形 ---
features="$app/ios/Features"
body First 20 first >"$features/First.swift"
git -C "$app" add ios/Features/First.swift
design_case 2 "名前だけ違う 20 行が別のファイルにあれば止める" "$features/Second.swift" "$(body Second 20 second)" "Second.swift:1: ここから 20 行以上が、ios/Features/First.swift:1 と同じ形"
design_case 0 "同じ形が 19 行なら通る" "$features/Second.swift" "$(body Second 19 second)"
design_case 0 "同じ行の繰り返しは、同じ形に数えない" "$features/Second.swift" "struct Second {"$'\n'"$(repeat 30 '    case value')"$'\n}'
body Third 20 third >"$features/Third.swift"
git -C "$app" add ios/Features/Third.swift
both=$(bash "$hooks" code-design-check "$features/First.swift" "$features/Third.swift" </dev/null 2>&1)
match "まとめて確かめる時は、同じ組を 1 回だけ出す" "$(grep -c '同じ形' <<<"$both")" 1
mkdir -p "$app/ios/FeaturesTests"
body FirstTests 20 first >"$app/ios/FeaturesTests/FirstTests.swift"
design_case 0 "テストのファイルは、同じ形でも見ない" "$app/ios/FeaturesTests/FirstTests.swift" "$(body FirstTests 20 first)"
body MigrationV001 20 first >"$features/MigrationV001.swift"
design_case 0 "通し番号のファイルは、同じ形でも見ない" "$features/MigrationV001.swift" "$(body MigrationV001 20 first)"
body First 20 first | sed 's/^struct/class/' >"$features/First.kt"
git -C "$app" add ios/Features/First.kt
design_case 2 "Kotlin も、名前だけ違う 20 行が別のファイルにあれば止める" "$features/Second.kt" "$(body Second 20 second | sed 's/^struct/class/')" "Second.kt:1: ここから 20 行以上が、ios/Features/First.kt:1 と同じ形"

record First f >"$features/Wallet.swift"
git -C "$app" add ios/Features/Wallet.swift
design_case 0 "保存プロパティと init だけの同じ並びは、同じ形に数えない" "$features/Account.swift" "$(record Account a)"
data_class First f >"$features/Wallet.kt"
git -C "$app" add ios/Features/Wallet.kt
design_case 0 "Kotlin の data class の同じ並びは、同じ形に数えない" "$features/Account.kt" "$(data_class Account a)"
mixed First f >"$features/Mixed.swift"
git -C "$app" add ios/Features/Mixed.swift
design_case 2 "保存プロパティの間に同じ処理の本体があれば止める" "$features/Mixer.swift" "$(mixed Mixer m)" "Mixer.swift:"
body_function() {
    local out="func $1() {"$'\n' i
    for ((i = 1; i < 21; i++)); do out+="    let $2${i} = make$2(${i})"$'\n'; done
    printf '%s' "${out}}"
}
body_function first f >"$features/Funcs.swift"
git -C "$app" add ios/Features/Funcs.swift
design_case 2 "同じ処理の本体を 20 行以上持つ関数は止める" "$features/Other.swift" "$(body_function second s)" "Other.swift:1: ここから 20 行以上が、ios/Features/Funcs.swift:1 と同じ形"

room First first >"$features/Wallet.kt"
git -C "$app" add ios/Features/Wallet.kt
design_case 0 "注釈の複数行の引数・注釈の付いた列・本体の無い関数は、同じ形に数えない" "$features/Account.kt" "$(room Account account)"
requirements First first >"$features/Source.swift"
git -C "$app" add ios/Features/Source.swift
design_case 0 "protocol の関数の要求だけの並びは、同じ形に数えない" "$features/Gateway.swift" "$(requirements Gateway second)"
annotated() {
    local out=$'@MainActor\n@Suppress("x")\nfunc '"$1"$'() {\n' i
    for ((i = 1; i < 21; i++)); do out+="    let $2${i} = make$2(${i})"$'\n'; done
    printf '%s' "${out}}"
}
annotated first f >"$features/Marked.swift"
git -C "$app" add ios/Features/Marked.swift
design_case 2 "注釈の付いた、本体を持つ同じ処理の関数は止める" "$features/Tagged.swift" "$(annotated second s)" "Tagged.swift:"

defaults() {
    local out="interface $1 {"$'\n' i params=("" "a: Int" "a: Int, b: Int" "a: Int, b: Int, c: Int") heads=("" "suspend " "private " "override " "inline ")
    for ((i = 0; i < 20; i++)); do out+="    ${heads[i % 5]}fun $2${i}(${params[i % 4]}) = make(${i})"$'\n'; done
    printf '%s' "${out}}"
}
defaults First first >"$features/Defaults.kt"
git -C "$app" add ios/Features/Defaults.kt
design_case 2 "interface の中の式の本体を持つ関数が同じ並びなら止める" "$features/Fallbacks.kt" "$(defaults Fallbacks second)" "Fallbacks.kt:"

# <先頭の行> <変数の頭> の、先頭の行の後に同じ処理の本体が続く Swift・Kotlin の中身
after_head() {
    local out="$1"$'\n' i
    for ((i = 1; i < 21; i++)); do out+="    let $2${i} = ${i}"$'\n'; done
    printf '%s' "${out}}"
}
after_head $'data class Plain(val id: String)\n\nfun run() {' first >"$features/Plain.kt"
git -C "$app" add ios/Features/Plain.kt
design_case 2 "本体の無い data class の後の関数の本体は、同じ形に数える" "$features/Other.kt" "$(after_head $'data class Other(val id: String)\n\nfun run() {' second)" "Other.kt:1: ここから 20 行以上が、ios/Features/Plain.kt:1 と同じ形"
calls() {
    local out="struct $1 {"$'\n    func run() {\n        let value = Wallet.init(\n' i
    for ((i = 1; i < 21; i++)); do out+="            label${i}: ${i},"$'\n'; done
    printf '%s' "${out}        )"$'\n    }\n}'
}
calls Calls >"$features/Calls.swift"
git -C "$app" add ios/Features/Calls.swift
design_case 2 "複数行の .init( の呼び出しの引数は、同じ形に数える" "$features/Calling.swift" "$(calls Calling)" "Calling.swift:1: ここから 20 行以上が、ios/Features/Calls.swift:1 と同じ形"
after_head $'struct Holder {\n    class var kind: Int {' first >"$features/Holder.swift"
git -C "$app" add ios/Features/Holder.swift
design_case 2 "class var の後の関数の本体は、同じ形に数える" "$features/Keeper.swift" "$(after_head $'struct Keeper {\n    class var kind: Int {' second)" "Keeper.swift:1: ここから 20 行以上が、ios/Features/Holder.swift:1 と同じ形"

# --- 共通の部品の一覧 ---
shared="$app/ios/Features/Shared/Model"
design_case 0 "一覧の文書が無ければ、Shared のプロトコルを見ない" "$shared/ScreenModel.swift" 'protocol ScreenModel {}'
printf '# 共通の部品\n\n`SettingsBoardModel` を使う。\n' >"$app/docs/architecture-parts.md"
design_case 2 "一覧に無い Shared のプロトコルは止める" "$shared/ScreenModel.swift" 'protocol ScreenModel {}' "ScreenModel.swift:1: Shared に置くプロトコルは、共通の部品の一覧（docs/architecture-parts.md）に載せる: ScreenModel"
design_case 0 "一覧にある Shared のプロトコルは通る" "$shared/SettingsBoardModel.swift" 'protocol SettingsBoardModel {}'
design_case 0 "Shared の外のプロトコルは見ない" "$app/ios/Features/Screens/HomeSource.swift" 'protocol HomeSource {}'
design_case 0 "git の外のファイルは、同じ形を見ない" "$work/Second.swift" "$(body Second 20 second)"

# --- make verify から呼ぶ時 ---
printf 'struct Case {}\n' >"$work/Named.swift"
out=$(bash "$hooks" code-design-check "$work/Named.swift" </dev/null 2>&1)
match "verify から呼ぶ時は、外れの行の頭に NG を付けて止める" "$?:$(grep -c '^NG .*Named.swift:1: ファイルの名前は' <<<"$out")" "2:1"
printf 'struct Broken {}\n\xff\n' >"$work/Broken.swift"
out=$(bash "$hooks" code-design-check "$work/Broken.swift" </dev/null 2>&1)
match "verify から呼ぶ時は、想定外の失敗でも NG で止める" "$?:$out" "2:NG *"

long="struct SnapshotTests {"$'\n'"$(repeat 399 '    // a')"$'\n}'
design_case 0 "リポジトリの .claude の下は見ない" "$app/.claude/snapshots/home/SnapshotTests.swift" "$long"
mkdir -p "$app/.claude/tools"
body First 20 tool >"$app/.claude/tools/Tool.swift"
git -C "$app" add .claude/tools/Tool.swift
body Second 20 second >"$features/Second.swift"
both=$(bash "$hooks" code-design-check "$features/Second.swift" </dev/null 2>&1)
match "リポジトリの .claude の下は、同じ形の相手にもしない" "$(grep -c '\.claude/tools' <<<"$both")" 0
design_case 2 "ルートの直下でない .claude は見る" "$app/ios/Features/.claude/Case.swift" "struct Case {"$'\n'"$(repeat 399 '    // a')"$'\n}' "Case.swift:401: 1 つのファイルは 400 行まで"
nested="$work/home/.claude/worktrees/app"
mkdir -p "$nested"
git -C "$nested" init -q
design_case 2 ".claude の下にできたワークツリーの中は見る" "$nested/Case.swift" "struct Case {"$'\n'"$(repeat 399 '    // a')"$'\n}' "Case.swift:401: 1 つのファイルは 400 行まで"

# --- 4 つのまとまりのモデル ---
grouped=$'@Observable\nfinal class Case {\n    let state: State\n    let input: Input\n    let output: Output\n\n    private let dependencies: Dependencies\n}'
design_case 0 "4 つのまとまりの let だけのモデルは通す" "$swift" "$grouped"
design_case 2 "まとまりのモデルの直下に var があれば止める" "$swift" $'@Observable\nfinal class Case {\n    let state: State\n\n    var count = 0\n}' "Case.swift:5: Case は 4 つのまとまりのモデルなので、保存プロパティの var を直下に置かない（今は 1 個）"
design_case 2 "まとまりのモデルの didSet は 1 個でも止める" "$swift" $'@Observable\nfinal class Case {\n    let input: Input\n\n    var count = 0 {\n        didSet {}\n    }\n}' "Case に didSet と willSet を書かない（今は 1 個）"
design_case 0 "まとまりのモデルの計算プロパティは数えない" "$swift" $'@Observable\nfinal class Case {\n    let state: State\n\n    var total: Int {\n        1\n    }\n}'
design_case 0 "dependencies だけを持つクラスは、まとまりのモデルにしない" "$swift" $'@Observable\nfinal class Case {\n    var count = 0\n\n    private let dependencies: Dependencies\n}'

part() {
    local out=$'extension Case {\n    @MainActor\n    @Observable\n    final class '"$1"$' {\n' i
    for ((i = 0; i < $2; i++)); do out+="        var value${i}: Int = 0"$'\n'; done
    for ((i = 0; i < $3; i++)); do out+="        var watched${i}: Int = 0 {"$'\n            didSet {}\n        }\n'; done
    printf '%s' "${out}    }"$'\n}'
}
design_case 0 "入れ子の State の var は 12 個まで通す" "$features/Case+State.swift" "$(part State 12 0)"
design_case 2 "入れ子の State の var が 13 個なら止める" "$features/Case+State.swift" "$(part State 13 0)" "State の保存プロパティの var は 12 個まで"
design_case 2 "入れ子の State の didSet は 1 個でも止める" "$features/Case+State.swift" "$(part State 1 1)" "まとまりの State に didSet と willSet を書かない（今は 1 個）"
design_case 0 "入れ子の Input は var の数を数えない" "$features/Case+Input.swift" "$(part Input 20 0)"
design_case 2 "入れ子の Input の didSet は 1 個でも止める" "$features/Case+Input.swift" "$(part Input 1 1)" "まとまりの Input に didSet と willSet を書かない"
rm -f "$features/Case+State.swift" "$features/Case+Input.swift"

design_case 0 "Output が input と state だけを読むなら通す" "$features/Case+Output.swift" $'extension Case {\n    final class Output {\n        let input: Input\n    }\n}\n\nextension Case.Output {\n    var total: Int {\n        input.count\n    }\n}'
design_case 2 "Output の中で await を使えば止める" "$features/Case+Output.swift" $'extension Case.Output {\n    func load() async {\n        await input.load()\n    }\n}' "Case+Output.swift:2: Output は input と state から値を出すだけにする"
design_case 2 "Output の中で DB を使えば止める" "$features/Case+Output.swift" $'extension Case {\n    final class Output {\n        let database: AppDatabase\n    }\n}' "Case+Output.swift:3: Output は input と state から値を出すだけにする"
design_case 0 "Output の外の await は見ない" "$features/Case+Output.swift" $'extension Case.Output {\n    var total: Int {\n        1\n    }\n}\n\nextension Case {\n    func load() async {\n        await run()\n    }\n}'
rm -f "$features/Case+Output.swift"

design_case 2 "dependencies を持つモデルで Date() を作れば止める" "$features/Case+Actions.swift" $'extension Case {\n    func save() async {\n        await dependencies.database.save(at: Date())\n    }\n}' "Case+Actions.swift:3: dependencies を持つモデルで、今の時刻を作らない"
design_case 0 "dependencies の時計から受け取れば通す" "$features/Case+Actions.swift" $'extension Case {\n    func save() async {\n        await dependencies.database.save(at: dependencies.clock.now)\n    }\n}'
design_case 0 "dependencies を持たないファイルの Date() は見ない" "$features/Case+Actions.swift" $'extension Case {\n    func save() async {\n        await database.save(at: Date())\n    }\n}'
rm -f "$features/Case+Actions.swift"

# --- 基準線 ---
base="$work/base"
mkdir -p "$base/Sources"
git -C "$base" init -q
printf '%s\n' "$(model 13 0 0)" >"$base/Sources/Case.swift"
printf 'struct Fine {}\n' >"$base/Sources/Fine.swift"
git -C "$base" add -A
out=$(bash "$hooks" code-design-check "$base/Sources/Case.swift" "$base/Sources/Fine.swift" </dev/null 2>&1)
match "基準線が無ければ、今ある外れを NG にする" "$?:$(grep -c '^NG ' <<<"$out")" "2:1"
out=$(bash "$hooks" code-design-check --write-baseline "$base/Sources/Case.swift" "$base/Sources/Fine.swift" </dev/null 2>&1)
match "--write-baseline は、今ある外れを基準線に書く" "$?:$out" "0:OK 基準線を書いた: *（1 件）"
check "基準線の行は、パスと文だけを持つ" grep -qxF "Sources/Case.swift: Case の保存プロパティの var は 12 個までにする（今は 13 個）。一緒に動く値を struct か enum にまとめる" "$base/.claude/code-design-baseline.txt"
expect OK "基準線にある外れは通す" bash "$hooks" code-design-check "$base/Sources/Case.swift" "$base/Sources/Fine.swift"
printf '%s\n' "$(model 14 0 0)" >"$base/Sources/Case.swift"
out=$(bash "$hooks" code-design-check "$base/Sources/Case.swift" "$base/Sources/Fine.swift" </dev/null 2>&1)
match "基準線より悪くなったら NG にする" "$?:$(grep -c '今は 14 個' <<<"$out")" "2:1"
printf 'struct Case {}\n' >"$base/Sources/Case.swift"
out=$(bash "$hooks" code-design-check "$base/Sources/Case.swift" "$base/Sources/Fine.swift" </dev/null 2>&1)
match "直った外れが基準線に残っていたら NG にする" "$?:$(grep -c '基準線にある外れが、もう無い。行を消す: Sources/Case.swift' <<<"$out")" "2:1"
out=$(bash "$hooks" code-design-check "$base/Sources/Fine.swift" </dev/null 2>&1)
match "渡していないファイルの基準線は、残っていても見ない" "$?" "0"
printf '%s\n' "$(model 13 0 0)" >"$base/Sources/Case.swift"
hook_case code-design-check 0 "編集の後も、基準線にある外れは知らせない" "$base/Sources/Case.swift" "$(model 13 0 0)"
bash "$hooks" code-design-check --write-baseline "$base/Sources/Fine.swift" </dev/null >/dev/null 2>&1
check "外れが無くなったら、--write-baseline は基準線のファイルを消す" test ! -e "$base/.claude/code-design-baseline.txt"

finish
