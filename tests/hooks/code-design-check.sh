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
now="今の時刻を引数やプロパティの既定値にしない"
design_case 2 "既定値に Date.init を書けば止める" "$swift" $'final class Case {\n    init(\n        database: AppDatabase,\n        now: @escaping () -> Date = Date.init\n    ) {}\n}' "Case.swift:4: $now"
design_case 2 "既定値に .now を返す閉じ込めを書けば止める" "$swift" $'final class Case {\n    init(\n        now: @escaping @MainActor () -> Date = { .now },\n        isOpen: (Item) -> Bool = Item.isOpen(for:)\n    ) {}\n}' "Case.swift:3: $now"
design_case 2 "既定値に Date() と Date.now を返す閉じ込めを書いても止める" "$swift" $'struct Case {\n    var now: () -> Date = { Date() }\n    var today: (@Sendable () -> Date)? = { Date.now }\n}' "Case.swift:3: $now"
design_case 2 "既定値の複数行の閉じ込めが今の時刻を作れば止める" "$swift" $'final class Case {\n    init(\n        day: @escaping () -> LocalDate = {\n            LocalDate(Date(), in: .current)\n        },\n        count: Int = 0\n    ) {}\n}' "Case.swift:3: $now"
design_case 2 "@autoclosure の既定値の Date() も止める" "$swift" $'struct Case {\n    func save(at now: @autoclosure () -> Date = Date()) {}\n}' "Case.swift:2: $now"
design_case 0 "時刻を返す関数を必須の引数で受け、呼ぶ側が Date.init を渡せば通る" "$swift" $'final class Case {\n    init(now: @escaping () -> Date, day: (@Sendable () -> LocalDate)? = nil) {}\n\n    static func live() -> Case {\n        Case(now: Date.init, day: { LocalDate(Date()) })\n    }\n\n    func child() -> Child {\n        Child(now: { .now })\n    }\n}'
design_case 0 "今の時刻を作らない関数の既定値と、時計から読む閉じ込めは通る" "$swift" $'struct Case {\n    var onSave: (Date) -> Void = { _ in }\n    var later: () -> Date = { .distantFuture }\n\n    init(clock: ScreenClock, now: (() -> Date)? = nil) {\n        let now: () -> Date = now ?? { clock.now }\n\n        let open: () -> AppDatabase = {\n            AppDatabase.file(now: Date())\n        }\n    }\n}'
design_case 2 "Kotlin の既定値に Instant.now() を返すラムダを書けば止める" "$kotlin" $'class Case(\n    private val database: AppDatabase,\n    private val now: () -> Instant = { Instant.now() },\n)' "Case.kt:3: $now"
design_case 2 "Kotlin の既定値に Clock.System::now と LocalDate::now を書いても止める" "$kotlin" $'class Case(\n    private val now: () -> Instant = Clock.System::now,\n    private val today: () -> LocalDate = LocalDate::now,\n)' "Case.kt:3: $now"
design_case 2 "Kotlin の既定値の複数行のラムダが今の時刻を作れば止める" "$kotlin" $'class Case(\n    private val today: () -> LocalDate = {\n        LocalDate.now(ZoneId.systemDefault())\n    },\n)' "Case.kt:2: $now"
design_case 0 "Kotlin で時刻を返す関数を必須の引数で受け、呼ぶ側が渡せば通る" "$kotlin" $'class Case(\n    private val now: () -> Instant,\n    private val onSave: (Instant) -> Unit = {},\n)\n\nfun live() = Case(now = { Instant.now() })\n\nfun other() = Case(now = Clock.System::now)\n\nfun clock(): () -> Instant = Instant::now\n\nval open: suspend () -> AppDatabase = {\n    AppDatabase.file(now = Instant.now())\n}'

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

design_case 2 "View から input に書けば止める" "$features/CaseView.swift" $'struct CaseView {\n    func choose() {\n        model.input.count = 1\n    }\n}' "CaseView.swift:3: モデルの input に、モデルの外から書かない"
design_case 2 "input を Bindable で包めば止める" "$features/CaseView.swift" $'struct CaseView {\n    var count: Binding<Int> {\n        Bindable(model.input).count\n    }\n}' "CaseView.swift:3: モデルの input に、モデルの外から書かない"
design_case 0 "モデルが自分の input に書くのは通す" "$features/CaseView.swift" $'struct CaseView {\n    func load() {\n        input.count = 1\n        self.input.count = 2\n    }\n}'
design_case 0 "input を読んで比べるだけなら通す" "$features/CaseView.swift" $'struct CaseView {\n    var isEmpty: Bool {\n        model.input.count == 0\n    }\n}'
design_case 2 "View から input の添字に書けば止める" "$features/CaseView.swift" $'struct CaseView {\n    func choose() {\n        model.input.items[0] = 1\n    }\n}' "CaseView.swift:3: モデルの input に、モデルの外から書かない"
design_case 2 "View から input の配列に足せば止める" "$features/CaseView.swift" $'struct CaseView {\n    func choose() {\n        model.input.items.append(1)\n    }\n}' "CaseView.swift:3: モデルの input に、モデルの外から書かない"
design_case 0 "weak self のクロージャから自分の input に書くのは通す" "$features/CaseView.swift" $'struct CaseView {\n    func load() {\n        task { [weak self] in\n            self?.input.count = 1\n            self?.input.items.append(1)\n        }\n    }\n}'
rm -f "$features/CaseView.swift"

design_case 2 "画面からモデルの dependencies を読めば止める" "$features/CaseView.swift" $'struct CaseView {\n    var body: some View {\n        Child(database: model.dependencies.database)\n    }\n}' "CaseView.swift:3: モデルの dependencies を、モデルの外から読まない"
design_case 0 "モデルが自分の dependencies を読むのは通る" "$features/CaseView.swift" $'struct CaseView {\n    func load() async {\n        await dependencies.database.load()\n        await self.dependencies.database.load()\n        await self?.dependencies.database.load()\n    }\n}'
design_case 0 "Environment のキーパスの dependencies は通る" "$features/CaseView.swift" $'struct CaseView {\n    @Environment(\\.dependencies) private var dependencies\n}'
design_case 2 "output 越しに state を読めば止める" "$features/CaseView.swift" $'struct CaseView {\n    var title: String {\n        model.output.state.title\n    }\n}' "CaseView.swift:3: output 越しに state と input を読まない"
rm -f "$features/CaseView.swift"
design_case 2 "Kotlin で output 越しに input を読めば止める" "$kotlin" $'class Case {\n    fun title(model: Other): String = model.output.input.title\n}' "Case.kt:2: output 越しに state と input を読まない"

# <State の var の数> <Boolean の数> の、4 つのまとまりの Kotlin のモデル
grouped() {
    local out=$'class Case(database: AppDatabase) {\n    val state = State()\n    val input = Input()\n    val output = Output(input, state)\n\n    class State {\n' i
    for ((i = 0; i < $1; i++)); do out+="        var value${i}: Int by mutableIntStateOf(0)"$'\n'; done
    for ((i = 0; i < $2; i++)); do out+="        var flag${i}: Boolean by mutableStateOf(false)"$'\n'; done
    out+=$'    }\n\n    class Input {\n        var list: List<Int> by mutableStateOf(emptyList())\n            internal set\n    }\n\n    class Output(\n        private val input: Input,\n        private val state: State,\n    ) {\n        val total: Int\n            get() = input.list.sum()\n    }\n}'
    printf '%s' "$out"
}

design_case 0 "Kotlin のまとまりのモデルは通る" "$kotlin" "$(grouped 9 3)"
design_case 2 "Kotlin のまとまりのモデルの直下に mutableStateOf を置けば止める" "$kotlin" $'class Case {\n    val state = State()\n\n    var count: Int by mutableIntStateOf(0)\n\n    class State\n}' "Case.kt:4: Case は 4 つのまとまりのモデルなので、mutableStateOf の var を直下に置かない"
design_case 0 "Kotlin でまとまりの型でない state の val は、まとまりのモデルと見ない" "$kotlin" $'class Case {\n    val state = remember()\n\n    var count: Int by mutableIntStateOf(0)\n}'
design_case 2 "Kotlin の State の var が 13 個なら止める" "$kotlin" "$(grouped 13 0)" "Case の State の mutableStateOf の var は 12 個まで"
design_case 2 "Kotlin の State の Boolean が 4 個なら止める" "$kotlin" "$(grouped 0 4)" "Case の State の Boolean は 3 個まで"
design_case 2 "Kotlin の Output で suspend を使えば止める" "$kotlin" $'class Case {\n    val output = Output()\n\n    class Output {\n        suspend fun load() {}\n    }\n}' "Case.kt:5: Output は input と state から値を出すだけにする"
design_case 0 "Kotlin の 1 行の Output の後ろのモデルの関数は見ない" "$kotlin" $'class Case {\n    val output = Output(state)\n\n    class State\n    class Output(private val state: State)\n\n    suspend fun load() {\n        dependencies.database.load()\n    }\n}'
design_case 0 "Kotlin の Output の外の suspend は見ない" "$kotlin" $'class Case {\n    val output = Output()\n\n    class Output {\n        val total: Int\n            get() = 1\n    }\n\n    suspend fun load() {}\n}'
design_case 2 "Kotlin の Output の拡張で suspend を使えば止める" "$work/CaseOutputText.kt" $'suspend fun Case.Output.load() {\n    run()\n}' "CaseOutputText.kt:1: Output は input と state から値を出すだけにする"
design_case 2 "Kotlin の Output の拡張で dependencies を使えば止める" "$work/CaseOutputText.kt" $'val Case.Output.title: String\n    get() = dependencies.name' "CaseOutputText.kt:2: Output は input と state から値を出すだけにする"
design_case 0 "Kotlin の Output の拡張が input と state だけを読むなら通る" "$work/CaseOutputText.kt" $'val Case.Output.title: String\n    get() = input.name\n\nsuspend fun Case.load() {\n    run()\n}'
rm -f "$work/CaseOutputText.kt"
design_case 2 "Kotlin で dependencies を持つモデルが Instant.now() を作れば止める" "$kotlin" $'class Case {\n    suspend fun save() {\n        dependencies.database.save(at = Instant.now())\n    }\n}' "Case.kt:3: dependencies を持つモデルで、今の時刻を作らない"
design_case 0 "Kotlin で dependencies の時計から受け取れば通る" "$kotlin" $'class Case {\n    suspend fun save() {\n        dependencies.database.save(at = dependencies.clock.now)\n    }\n}'
design_case 2 "Kotlin の画面から input に書けば止める" "$kotlin" $'class Case {\n    fun choose(model: Other) {\n        model.input.count = 1\n    }\n}' "Case.kt:3: モデルの input に、モデルの外から書かない"
design_case 0 "Kotlin のモデルが自分の input に書くのは通る" "$kotlin" $'class Case {\n    fun load() {\n        input.count = 1\n        this.input.count = 2\n        this@Case.input.count = 3\n    }\n}'

# --- 画面の形 ---
view="$features/CaseView.swift"
# <View の中の行> を持つ Swift の View
screen() {
    printf 'struct CaseView: View {\n%s\n}' "$1"
}
design_case 0 "モデルと layout と SwiftUI の持ち物だけの View は通る" "$view" "$(screen $'    @State private var model: CaseModel\n    @State private var layout = Layout()\n    @FocusState private var focus: Field?\n    @Namespace private var space\n    @GestureState private var drag: CGFloat = 0\n    @Environment(\\.dismiss) private var dismiss\n    @Bindable var parent: OtherModel\n    let child: ChildModel\n\n    struct Layout {\n        var width: CGFloat = 0\n        var frame: CGRect?\n        var heights: [Int: CGFloat] = [:]\n        var frames: [Entry.ID: CGRect] = [:]\n        var offsets: [CGPoint] = []\n        var size = CGSize.zero\n        var insets = EdgeInsets()\n        var position = ScrollPosition()\n        var glow: Double = 0\n        var turn = Angle.zero\n        static let limit = 3\n\n        var isWide: Bool {\n            width > 600\n        }\n    }')"
design_case 0 "初めの値で作るモデル・子のモデル・入れ子のモデル・型引数のあるモデルは通る" "$view" "$(screen $'    @State private var appIcon = AppIconListModel()\n    @State var home: HomeModel?\n    @State var board: Spec.Model\n    @State var weekStart: MenuValueModel<Weekday>\n    @State private var layout: CaseView.Layout')"
design_case 2 "View の @State の Bool は止める" "$view" "$(screen $'    @State private var isEditing = false')" "CaseView.swift:2: View の @State に置けるのは、モデルと layout だけにする: isEditing。意味のある状態は、モデルの state に移す"
design_case 2 "View の @State の、出しているシートと選んでいる物は止める" "$view" "$(screen $'    @State var sheet: Sheet?\n    @State private var selection: Entry.ID?')" "CaseView.swift:3: View の @State に置けるのは、モデルと layout だけにする: selection。意味のある状態"
design_case 2 "View の @State の、入力中の文字は止める" "$view" "$(screen $'    @State private var text = ""')" "モデルと layout だけにする: text。意味のある状態は、モデルの state に移す"
design_case 0 "子のモデルの配列と Optional は通る" "$view" "$(screen $'    @State private var items: [ItemModel] = []\n    @State private var next: ItemModel? = nil')"
design_case 2 "View の @State の寸法は、Layout にまとめるよう止める" "$view" "$(screen $'    @State private var width: CGFloat = 0')" "CaseView.swift:2: View の @State に置けるのは、モデルと layout だけにする: width。見た目の値は、入れ子の struct Layout にまとめる"
design_case 2 "名前が Model で終わらない状態の型は止める" "$view" "$(screen $'    @State private var flow = EntryFlow()')" "モデルと layout だけにする: flow。意味のある状態"
design_case 2 "寸法だけを持つ型の @State は、Layout にまとめるよう止める" "$view" "$(screen $'    @State private var frame = FrameHolder()')"$'\n\nprivate extension CaseView {\n    final class FrameHolder {\n        var rect: CGRect = .zero\n    }\n}' "CaseView.swift:2: View の @State に置けるのは、モデルと layout だけにする: frame。見た目の値は、入れ子の struct Layout にまとめる"
design_case 2 "寸法でない値も持つ型の @State は、意味のある状態として止める" "$view" "$(screen $'    @State private var flow = Flow()')"$'\n\nprivate struct Flow {\n    var width: CGFloat = 0\n    var isOpen: Bool = false\n}' "モデルと layout だけにする: flow。意味のある状態"
design_case 2 "ViewModifier の @State も止める" "$features/CaseLift.swift" $'struct CaseLift: ViewModifier {\n    @State private var isLifted = false\n}' "CaseLift.swift:2: View の @State に置けるのは、モデルと layout だけにする: isLifted"
design_case 0 "プレビューの @Previewable の @State は見ない" "$view" "$(screen $'    let title: String')"$'\n\n#Preview {\n    @Previewable @State var text = "a"\n    @Previewable @State var isOn = false\n}'
design_case 0 "コメントと文字列の中の @State は見ない" "$view" "$(screen $'    // @State private var isOn = false\n    let note = "@State var isOn = false"')"
design_case 2 "Layout の Bool は止める" "$view" "$(screen $'    @State private var layout = Layout()\n\n    struct Layout {\n        var width: CGFloat = 0\n        var isOpen: Bool = false\n    }')" "CaseView.swift:6: Layout に置けるのは、寸法・位置・スクロールの型だけにする: isOpen。意味のある状態は、モデルの state に移す"
design_case 2 "Layout の Int・String・ID・ドメインの型は止める" "$view" "$(screen $'    struct Layout {\n        var page: Int?\n        var text: String\n        var open: Entry.ID?\n        var days: [LocalDate]\n    }')" "CaseView.swift:6: Layout に置けるのは、寸法・位置・スクロールの型だけにする: days"
design_case 2 "Layout の let も見る" "$view" "$(screen $'    struct Layout {\n        let isOpen: Bool\n    }')" "CaseView.swift:3: Layout に置けるのは、寸法・位置・スクロールの型だけにする: isOpen"
design_case 2 "Layout の辞書は、値の型で見る" "$view" "$(screen $'    struct Layout {\n        var flags: [CGFloat: Bool] = [:]\n    }')" "Layout に置けるのは、寸法・位置・スクロールの型だけにする: flags"
design_case 2 "Layout の型を読み取れない値は、型を書くよう止める" "$view" "$(screen $'    struct Layout {\n        var width = 0\n    }')" "CaseView.swift:3: Layout の値には、型を書く: width"
design_case 2 "拡張に置いた Layout の中も見る" "$features/CaseView+Layout.swift" $'extension CaseView {\n    struct Layout {\n        var isOpen = false\n    }\n}' "CaseView+Layout.swift:3: Layout の値には、型を書く: isOpen"
design_case 0 "DesignSystem の部品の @State は見ない" "$app/ios/DesignSystem/Components/CaseSwitch.swift" $'struct CaseSwitch: View {\n    @State private var isPressed = false\n    @State private var width: CGFloat = 0\n}'
design_case 0 "テストの View の @State は見ない" "$app/ios/FeaturesTests/CaseViewTests.swift" $'struct CaseViewTests: View {\n    @State private var isOn = false\n}'
rm -f "$features/CaseLift.swift" "$features/CaseView+Layout.swift"

# --- 画面の非同期 ---
effect="画面で Task を始めない。モデルの口から始め、結果は state の変化で受ける"
# <Task を入れる変数の宣言> <取り消しの行> の、View でない型と ViewModifier が同じファイルにある画面だけの非同期
scroller() {
    printf '@Observable\nfinal class CaseScroll {\n%s\n\n    func follow() {\n        task = Task {\n            await run()\n        }\n    }\n\n    func stop() {\n%s\n    }\n}\n\nprivate struct CaseScrollModifier: ViewModifier {}' "$1" "$2"
}
design_case 2 "View の中の Task は止める" "$view" "$(screen $'    func save() {\n        Task {\n            await model.save()\n        }\n    }')" "CaseView.swift:3: $effect"
design_case 2 "View の中の Task( と Task.detached と、型引数のある Task も止める" "$view" "$(screen $'    func save() {\n        Task(priority: .high) {}\n        Task.detached {}\n        Task<Void, Never> {}\n    }')" "CaseView.swift:5: $effect"
design_case 2 "クロージャの中で @MainActor を付けた Task も止める" "$view" "$(screen $'    var body: some View {\n        Button("a") {\n            Task { @MainActor in\n                await model.save()\n            }\n        }\n    }')" "CaseView.swift:4: $effect"
design_case 0 "View の .task・Task.sleep・addTask・型の宣言・コメントと文字列は通る" "$view" "$(screen $'    let pending: Task<Void, Never>?\n\n    var body: some View {\n        Text("Task { }")\n            .task {\n                try? await Task.sleep(for: .seconds(1))\n                await Task.yield()\n                // Task { await model.save() }\n                await withTaskGroup(of: Void.self) { group in\n                    group.addTask { await model.load() }\n                }\n            }\n            .task(id: model.state.day) {\n                if !Task.isCancelled {\n                    await model.load()\n                }\n            }\n    }\n\n    func start() -> Task<Void, Never> {\n        model.perform { await $0.save() }\n    }')"
design_case 2 "View を拡張するファイルの Task も止める" "$features/CaseView+Actions.swift" $'extension CaseView {\n    func save() {\n        Task {\n            await model.save()\n        }\n    }\n}' "CaseView+Actions.swift:3: $effect"
design_case 2 "extension View のファイルの Task も止める" "$features/CaseNotice.swift" $'extension View {\n    func notice(_ model: CaseModel) -> some View {\n        onTapGesture {\n            Task {}\n        }\n    }\n}' "CaseNotice.swift:4: $effect"
design_case 2 "ViewModifier の Task も止める" "$features/CaseLift.swift" $'struct CaseLift: ViewModifier {\n    func lift() {\n        Task {}\n    }\n}' "CaseLift.swift:3: $effect"
design_case 0 "View でない型だけのファイルの Task は見ない" "$features/CaseModel.swift" $'@Observable\nfinal class CaseModel {\n    func perform() {\n        Task {\n            await save()\n        }\n    }\n}'
design_case 0 "View でない型を拡張するファイルの Task は見ない" "$features/CaseModel+Pro.swift" $'extension CaseModel {\n    func watch() {\n        Task {}\n    }\n}'
design_case 0 "View の外の Task? の保存プロパティに入れて取り消す Task は通る" "$features/CaseScroll.swift" "$(scroller $'    private var task: Task<Void, Never>?' $'        task?.cancel()\n        task = nil')"
design_case 0 "@ObservationIgnored の保存プロパティと self. の代入も通る" "$features/CaseScroll.swift" "$(scroller $'    @ObservationIgnored private var task: Task<Void, Never>? = nil' $'        self.task?.cancel()' | sed 's/        task = Task/        self.task = Task/')"
design_case 0 "型引数の中の Task は通る" "$view" "$(screen $'    let tasks = Dictionary<UUID, Task<Void, Never>>()\n    let all = Set<Task<Void, Never>>()')"
design_case 0 "1 行で宣言した ViewModifier の後の型の、取り消す Task は通る" "$features/CaseScroll.swift" $'private struct CaseScrollModifier: ViewModifier { func body(content: Content) -> some View { content } }\n\n@Observable\nfinal class CaseScroll {\n    private var task: Task<Void, Never>?\n\n    func follow() {\n        task?.cancel()\n        task = Task {}\n    }\n}'
design_case 2 "保存プロパティに入れても、取り消さない Task は止める" "$features/CaseScroll.swift" "$(scroller $'    private var task: Task<Void, Never>?' $'        task = nil')" "CaseScroll.swift:6: $effect"
design_case 2 "画面のファイルの View でない型でも、入れずに始める Task は止める" "$features/CaseScroll.swift" "$(scroller $'    private var task: Task<Void, Never>?' $'        task?.cancel()\n        Task {}')" "CaseScroll.swift:13: $effect"
design_case 2 "View の @State に入れる Task は止める" "$view" "$(screen $'    @State private var task: Task<Void, Never>?\n\n    func save() {\n        task?.cancel()\n        task = Task {}\n    }')" "CaseView.swift:6: $effect"
design_case 2 "View の中で宣言した保存プロパティに入れる Task は止める" "$view" "$(screen $'    private var task: Task<Void, Never>?\n\n    init() {\n        task = Task {}\n        task?.cancel()\n    }')" "CaseView.swift:5: $effect"
design_case 2 "View からほかの型のプロパティに入れる Task は止める" "$view" "$(screen $'    func save() {\n        holder.task?.cancel()\n        holder.task = Task {}\n    }')"$'\n\nfinal class CaseViewHolder {\n    var task: Task<Void, Never>?\n}' "CaseView.swift:4: $effect"
design_case 0 "DesignSystem の部品の Task は見ない" "$app/ios/DesignSystem/Components/CaseSwitch.swift" $'struct CaseSwitch: View {\n    func flash() {\n        Task {}\n    }\n}'
design_case 0 "テストの View の Task は見ない" "$app/ios/FeaturesTests/CaseViewTests.swift" $'struct CaseViewTests: View {\n    func run() {\n        Task {}\n    }\n}'
rm -f "$view" "$features"/Case{Lift,Notice,Model,Model+Pro,Scroll,View+Actions}.swift

compose="$features/CaseView.kt"
# <関数の中の行> を持つ Kotlin の Composable
composable() {
    printf '@Composable\nfun CaseView(model: CaseModel) {\n%s\n}' "$1"
}
design_case 0 "モデルと Layout と Compose の持ち物だけの Composable は通る" "$compose" "$(composable $'    val child = remember { ChildModel(model.makeChild()) }\n    val layout = remember { Layout() }\n    val scroll = rememberScrollState()\n    val list = rememberLazyListState()\n    val focus = remember { FocusRequester() }\n    val total by remember { derivedStateOf { model.output.total } }')"$'\n\nprivate class Layout {\n    var width: Dp by mutableStateOf(0.dp)\n    var dragY by mutableFloatStateOf(0f)\n    var origin by mutableStateOf(Offset.Zero)\n    var size by mutableStateOf(IntSize.Zero)\n    var frame by mutableStateOf<Rect?>(null)\n    var heights: Map<Int, Float> by mutableStateOf(emptyMap())\n    var scale = 1f\n\n    val isWide: Boolean\n        get() = width > 600.dp\n}'
design_case 2 "Composable で mutableStateOf を作れば止める" "$compose" "$(composable $'    var isEditing by remember { mutableStateOf(false) }')" "CaseView.kt:3: Composable の関数で、状態を直接作らない（mutableStateOf: isEditing）。意味のある状態は、モデルの State に移す"
design_case 2 "Composable で rememberSaveable の中に作っても止める" "$compose" "$(composable $'    var sheet by rememberSaveable(stateSaver = Sheet.Saver) {\n        mutableStateOf<Sheet?>(null)\n    }')" "CaseView.kt:4: Composable の関数で、状態を直接作らない（mutableStateOf）。意味のある状態は、モデルの State に移す"
design_case 2 "Composable で mutableIntStateOf を作れば止める" "$compose" "$(composable $'    var round by remember { mutableIntStateOf(0) }')" "状態を直接作らない（mutableIntStateOf: round）。意味のある状態は、モデルの State に移す"
design_case 2 "Composable で作る寸法は、Layout にまとめるよう止める" "$compose" "$(composable $'    var dragY by remember { mutableFloatStateOf(0f) }\n    var size by remember { mutableStateOf(IntSize.Zero) }')" "CaseView.kt:3: Composable の関数で、状態を直接作らない（mutableFloatStateOf: dragY）。見た目の値は、class Layout にまとめる"
design_case 2 "private な Composable の中も見る" "$compose" "$(composable $'    Row {}')"$'\n\n@Composable\nprivate fun Row() {\n    val open = remember { mutableStateOf<Sheet?>(null) }\n}' "CaseView.kt:8: Composable の関数で、状態を直接作らない（mutableStateOf: open）"
design_case 0 "同じファイルの、モデルでない状態のクラスの mutableStateOf は見ない" "$compose" $'class CaseViewState(context: Context) {\n    var isAllowed: Boolean by mutableStateOf(true)\n}\n\n@Composable\nfun rememberCaseViewState(): CaseViewState {\n    val context = LocalContext.current\n    return remember(context) { CaseViewState(context) }\n}'
design_case 0 "@Preview の関数の中は見ない" "$compose" "$(composable $'    Text(model.state.title)')"$'\n\n@Preview(showBackground = true)\n@Composable\nprivate fun CaseViewPreview() {\n    var text by remember { mutableStateOf("a") }\n}'
design_case 0 "Composable の無いファイルの関数は見ない" "$features/CaseFlow.kt" $'fun caseFlow(): MutableState<Boolean> {\n    return mutableStateOf(false)\n}'
design_case 0 "コメントと文字列の中の mutableStateOf は見ない" "$compose" "$(composable $'    // var a by remember { mutableStateOf(false) }\n    Text("mutableStateOf(false)")')"
design_case 2 "Kotlin の Layout の Boolean は止める" "$compose" "$(composable $'    val layout = remember { Layout() }')"$'\n\nprivate class Layout {\n    var width by mutableStateOf(0.dp)\n    var isOpen by mutableStateOf(false)\n}' "CaseView.kt:8: Layout の値には、型を書く: isOpen"
design_case 2 "Kotlin の Layout の Int・String・ID は止める" "$compose" $'private class Layout {\n    var page by mutableIntStateOf(0)\n    var text: String by mutableStateOf("")\n    var open by mutableStateOf<Identifier<Entry>?>(null)\n}' "CaseView.kt:4: Layout に置けるのは、寸法と位置の型だけにする: open。意味のある状態は、モデルの State に移す"
design_case 2 "修飾語が 2 つある Kotlin の Layout も見る" "$compose" $'private data class Layout {\n    var on = false\n}' "CaseView.kt:2: Layout"
design_case 2 "Kotlin の Layout の Map は、値の型で見る" "$compose" $'private class Layout {\n    var flags: Map<Float, Boolean> by mutableStateOf(emptyMap())\n}' "CaseView.kt:2: Layout に置けるのは、寸法と位置の型だけにする: flags"
design_case 0 "designsystem の部品の mutableStateOf は見ない" "$app/android/designsystem/components/CaseSwitch.kt" "$(composable $'    var isPressed by remember { mutableStateOf(false) }' | sed 's/CaseView/CaseSwitch/')"
design_case 0 "テストの Composable の mutableStateOf は見ない" "$app/android/src/test/CaseViewTest.kt" "$(composable $'    var isOn by remember { mutableStateOf(false) }')"
kotlin_effect="モデルの口から始め、結果は State の変化で受ける。画面の寿命の読み込みは、LaunchedEffect からモデルの関数を呼ぶ"
design_case 2 "Composable の rememberCoroutineScope は止める" "$compose" "$(composable $'    val scope = rememberCoroutineScope()')" "CaseView.kt:3: 画面でコルーチンを始めない（rememberCoroutineScope）。$kotlin_effect"
design_case 2 "Composable の関数で、スコープから始める launch と async は止める" "$compose" "$(composable $'    Button(onClick = { model.scope.launch { model.save() } }) {}\n    val loaded = model.scope.async(Dispatchers.IO) { model.load() }\n    model.viewModelScope\n        .launch(start = CoroutineStart.LAZY) {}')" "CaseView.kt:6: 画面でコルーチンを始めない（launch）。$kotlin_effect"
design_case 2 "スコープから始める async も、行を示して止める" "$compose" "$(composable $'    val loaded = scope.async { model.load() }')" "CaseView.kt:3: 画面でコルーチンを始めない（async）"
design_case 2 "画面のファイルで CoroutineScope と MainScope を作れば止める" "$compose" "$(composable $'    val scope = remember { CoroutineScope(Dispatchers.Main) }')"$'\n\nprivate class CaseViewRunner {\n    private val scope = MainScope()\n}' "CaseView.kt:7: 画面でコルーチンを始めない（MainScope）"
design_case 2 "画面のファイルの GlobalScope は止める" "$compose" "$(composable $'    Button(onClick = { GlobalScope.launch { model.save() } }) {}')" "CaseView.kt:3: 画面でコルーチンを始めない（GlobalScope）"
design_case 0 "LaunchedEffect・DisposableEffect と、その中の launch は通る" "$compose" "$(composable $'    LaunchedEffect(model) {\n        model.observe()\n    }\n    LaunchedEffect(model.state.day) {\n        launch { model.load() }\n        launch(Dispatchers.Default) { model.count() }\n        coroutineScope {\n            val total = async { model.total() }\n            total.await()\n        }\n    }\n    DisposableEffect(model) {\n        onDispose { model.stop() }\n    }')"
design_case 0 "ActivityResult の launch( と、launch という名前の値は通る" "$compose" "$(composable $'    val launcher = rememberLauncherForActivityResult(RequestPermission()) { model.allow(it) }\n    state.launch = {\n        launcher.launch(Manifest.permission.POST_NOTIFICATIONS)\n    }\n    Button(onClick = { if (model.state.isAsking) picker.launch(PickVisualMediaRequest(ImageOnly)) else { state.launch() } }) {}\n    when (val launch = model.launch) {}')"
design_case 0 "import とスコープの型の名前・コメントと文字列は通る" "$compose" $'import androidx.compose.runtime.rememberCoroutineScope\nimport kotlinx.coroutines.CoroutineScope\nimport kotlinx.coroutines.GlobalScope\nimport kotlinx.coroutines.launch\n\n'"$(composable $'    // val scope = rememberCoroutineScope()\n    /* scope.launch { } */\n    Text("scope.launch { CoroutineScope(Dispatchers.IO) }")\n    CaseRow(model.state.rows)')"$'\n\nprivate suspend fun CoroutineScope.follow(scope: CoroutineScope, model: CaseModel) {\n    launch { model.load() }\n}'
design_case 0 "Composable の無いファイルの viewModelScope.launch と CoroutineScope は見ない" "$features/CaseModel.kt" $'class CaseModel : ViewModel() {\n    private val scope = CoroutineScope(Dispatchers.IO)\n\n    fun perform() {\n        viewModelScope.launch { save() }\n    }\n}\n\nfun CaseModel.reload() {\n    scope.launch { load() }\n}'
design_case 0 "画面のファイルでも、クラスの中の viewModelScope.launch は見ない" "$compose" "$(composable $'    Text(model.state.title)')"$'\n\nclass CaseViewModel : ViewModel() {\n    fun perform() {\n        viewModelScope.launch { save() }\n    }\n}'
design_case 0 "@Preview の関数のコルーチンは見ない" "$compose" "$(composable $'    Text(model.state.title)')"$'\n\n@Preview\n@Composable\nprivate fun CaseViewPreview() {\n    val scope = rememberCoroutineScope()\n    Button(onClick = { scope.launch { } }) {}\n}'
design_case 0 "designsystem の部品のコルーチンは見ない" "$app/android/designsystem/components/CaseSwitch.kt" "$(composable $'    val scope = rememberCoroutineScope()\n    Button(onClick = { scope.launch { offset.animateTo(0f) } }) {}' | sed 's/CaseView/CaseSwitch/')"
design_case 0 "テストの Composable のコルーチンは見ない" "$app/android/src/test/CaseViewTest.kt" "$(composable $'    val scope = rememberCoroutineScope()\n    scope.launch { }')"
rm -f "$compose" "$features/CaseFlow.kt"

# --- まとまりの宣言 ---
design_case 2 "まとまりを全部 var で持てば止める" "$swift" $'@Observable\nfinal class Case {\n    var state: State\n    var input = Input()\n\n    private let dependencies: Dependencies\n}' "Case.swift:3: Case のまとまりは let で持つ: state"
design_case 2 "let のまとまりに var のまとまりが混じれば止める" "$swift" $'@Observable\nfinal class Case {\n    let state: State\n    public var output: Case.Output\n}' "Case.swift:4: Case のまとまりは let で持つ: output"
design_case 0 "state という名前の var が 1 つだけのクラスは、まとまりのモデルと見ない" "$swift" $'@Observable\nfinal class Case {\n    var state: State = .idle\n    var count = 0\n}'
design_case 2 "@Observable のクラスが DB を直接持てば止める" "$swift" $'@Observable\nfinal class Case {\n    private(set) var isOn = false\n\n    private let database: AppDatabase\n}' "Case.swift:5: Case は DB と時計を直接持たない: database"
design_case 2 "@Observable のクラスが時計を直接持てば止める" "$swift" $'@Observable\nfinal class Case {\n    let state: State\n    let clock = ScreenClock.system\n}' "Case.swift:4: Case は DB と時計を直接持たない: clock"
design_case 0 "@Observable でない型と、DB を返す関数の値は見ない" "$swift" $'struct Case {\n    let database: AppDatabase\n}\n\n@Observable\nfinal class CaseFlag {\n    private let open: () -> AppDatabase\n}'
design_case 2 "Input の public な var に (set) が無ければ止める" "$features/Case+Input.swift" $'extension Case {\n    @Observable\n    public final class Input {\n        public var count = 0\n    }\n}' "Case+Input.swift:4: Input の public な var は、public internal(set) にする: count"
design_case 0 "Input の internal(set) の var・public でない var・計算プロパティは通る" "$features/Case+Input.swift" $'extension Case {\n    @Observable\n    public final class Input {\n        public internal(set) var count = 0\n        var items: [Int] = []\n\n        public var total: Int {\n            count\n        }\n    }\n}'
design_case 2 "共通の Input の型の public な var も止める" "$features/BoardInput.swift" $'@Observable\npublic final class BoardInput<Value> {\n    public var value: Value?\n}' "BoardInput.swift:3: BoardInput の public な var は、public internal(set) にする: value"
design_case 2 "Dependencies の中身が public なら止める" "$swift" $'final class Case {}\n\nextension Case {\n    public struct Dependencies {\n        public let database: AppDatabase\n        let clock: ScreenClock\n    }\n}' "Case.swift:5: Dependencies の中身を public にしない: database"
design_case 0 "Dependencies の中身が public でなければ通る" "$swift" $'final class Case {}\n\npublic struct CaseDependencies {\n    let database: AppDatabase\n}'
design_case 2 "dependencies の無いファイルの Output の Date() も止める" "$features/Case+Output.swift" $'extension Case.Output {\n    var isLate: Bool {\n        state.due < Date()\n    }\n}' "Case+Output.swift:3: Output で今の時刻を作らない"
rm -f "$features/Case+Input.swift" "$features/BoardInput.swift" "$features/Case+Output.swift"

design_case 2 "Kotlin のまとまりを var で持てば止める" "$kotlin" $'class Case {\n    var state = State()\n\n    class State\n}' "Case.kt:2: Case のまとまりは val で持つ: state"
design_case 2 "Kotlin の Input の var に internal set が無ければ止める" "$kotlin" $'class Case {\n    val input = Input()\n\n    class Input {\n        var count: Int by mutableIntStateOf(0)\n    }\n}' "Case.kt:5: Case の Input の var は、internal set にする: count"
design_case 0 "Kotlin の Input の private set と internal の var は通る" "$kotlin" $'class Case {\n    val input = Input()\n\n    class Input(\n        val id: String,\n    ) {\n        var count: Int by mutableIntStateOf(0)\n            private set\n\n        internal var name: String by mutableStateOf("")\n    }\n}'
design_case 2 "Kotlin の Input に書き換えられる集まりを置けば止める" "$kotlin" $'class Case {\n    val input = Input()\n\n    class Input {\n        val items = mutableStateListOf<Int>()\n    }\n}' "Case.kt:5: Case の Input に、書き換えられる集まりを置かない"
design_case 2 "Kotlin の dependencies が private でなければ止める" "$kotlin" $'class Case(database: AppDatabase) {\n    val state = State()\n\n    internal val dependencies = Dependencies(database)\n\n    class State\n}' "Case.kt:4: Case の dependencies は、private val にする"
design_case 2 "Kotlin の状態のクラスが DB を直接持てば止める" "$kotlin" $'class Case(\n    private val database: AppDatabase,\n) {\n    var isOn: Boolean by mutableStateOf(false)\n        private set\n}' "Case.kt:2: Case は DB と時計を直接持たない: database"
design_case 0 "Kotlin の状態を持たないクラスが DB を持つのは見ない" "$kotlin" $'class Case(\n    private val database: AppDatabase,\n) {\n    suspend fun load() = database.load()\n}'
design_case 0 "Kotlin のモデルの外の Dependencies のクラスは DB を持ってよい" "$kotlin" $'class Case {\n    val state = State()\n\n    class State\n}\n\nprivate class Dependencies(\n    val database: AppDatabase,\n    val clock: Clock,\n)'
design_case 0 "Kotlin のモデルでないクラスの dependencies は見ない" "$kotlin" $'class Case : Application() {\n    val dependencies by lazy { CaseDependencies(this) }\n}'
design_case 2 "Kotlin の Input の引数の var は、internal var か本体に移すよう知らせる" "$kotlin" $'class Case {\n    val input = Input()\n\n    class Input(\n        var name: String,\n    )\n}' "Case.kt:5: Case の Input の引数の var は、internal var にするか、本体の var に移して internal set にする: name"
with_arguments=$(grouped 13 0)
design_case 2 "Kotlin で引数のある State の var も数える" "$kotlin" "${with_arguments/$'    class State {'/$'    class State(\n        today: Int,\n    ) {'}""Case の State の mutableStateOf の var は 12 個まで"
design_case 2 "Kotlin で引数のある Output の中も見る" "$kotlin" $'class Case {\n    val output = Output(state)\n\n    class Output(\n        private val state: State,\n    ) {\n        suspend fun load() {}\n    }\n}' "Case.kt:7: Output は input と state から値を出すだけにする"
design_case 2 "Kotlin の Output で Instant.now() を作れば止める" "$kotlin" $'class Case {\n    val output = Output()\n\n    class Output {\n        val isLate: Boolean\n            get() = due < Instant.now()\n    }\n}' "Case.kt:6: Output で今の時刻を作らない"
design_case 2 "Kotlin で dependencies を持つモデルが LocalDate.now() を作れば止める" "$kotlin" $'class Case {\n    suspend fun save() {\n        dependencies.database.save(on = LocalDate.now())\n    }\n}' "Case.kt:3: dependencies を持つモデルで、今の時刻を作らない"
design_case 2 "Kotlin の画面から input の一覧に足せば止める" "$kotlin" $'class Case {\n    fun choose(model: Other) {\n        model.input.items.add(1)\n    }\n}' "Case.kt:3: モデルの input に、モデルの外から書かない"

# --- モデルを別のモジュールに置いたアプリ ---
sources="$app/ios/Packages/CaseApp/Sources"
mkdir -p "$sources/FeatureModels" "$sources/Features"
printf '@Observable\npublic final class CaseModel {\n    public let input: Input\n\n    let dependencies: Dependencies\n}\n' >"$sources/FeatureModels/CaseModel.swift"
writes=$'struct CaseView {\n    func choose() {\n        model.input.count = 1\n    }\n}'
reads=$'struct CaseView {\n    var body: some View {\n        Child(database: model.dependencies.database)\n    }\n}'
design_case 0 "モデルが別のモジュールにある画面は、input への書き込みを型に任せる" "$sources/Features/CaseView.swift" "$writes"
design_case 0 "モデルが別のモジュールにある画面は、dependencies の読み出しを型に任せる" "$sources/Features/CaseView.swift" "$reads"
design_case 2 "モデルのモジュールの中では、ほかのモデルの input への書き込みを止める" "$sources/FeatureModels/OtherModel.swift" $'final class OtherModel {\n    func choose() {\n        model.input.count = 1\n    }\n}' "OtherModel.swift:3: モデルの input に、モデルの外から書かない"
printf '@Observable\nfinal class SideModel {\n    let state: State\n\n    func load() {\n        let input = 1\n    }\n}\n' >"$sources/Features/SideModel.swift"
design_case 0 "画面のモジュールの、input を持たないモデルと関数の中の値は数えない" "$sources/Features/CaseView.swift" "$writes"
printf '@Observable\nfinal class SideModel {\n    let input: Input\n}\n' >"$sources/Features/SideModel.swift"
design_case 2 "画面と同じモジュールに input を持つモデルがあれば、書き込みを止める" "$sources/Features/CaseView.swift" "$writes" "CaseView.swift:3: モデルの input に、モデルの外から書かない"
design_case 0 "input を持つモデルだけでは、dependencies の読み出しを止めない" "$sources/Features/CaseView.swift" "$reads"
printf '@Observable\nfinal class SideModel {\n    let dependencies: Dependencies\n}\n' >"$sources/Features/SideModel.swift"
design_case 2 "画面と同じモジュールに dependencies を持つモデルがあれば、読み出しを止める" "$sources/Features/CaseView.swift" "$reads" "CaseView.swift:3: モデルの dependencies を、モデルの外から読まない"
rm -f "$sources/Features/SideModel.swift"
printf 'struct CaseList: View {}\n' >"$sources/Features/CaseList.swift"
starts=$'@Observable\nfinal class CaseDrag {\n    func arm() {\n        Task {}\n    }\n}'
design_case 2 "モデルを持たない画面のモジュールでは、@Observable のクラスの Task も止める" "$sources/Features/CaseDrag.swift" "$starts" "CaseDrag.swift:4: $effect"
design_case 2 "画面のモジュールの @Observable のクラスを拡張するファイルの Task も止める" "$sources/Features/CaseDrag+Arm.swift" $'extension CaseDrag {\n    func rearm() {\n        Task {}\n    }\n}' "CaseDrag+Arm.swift:3: $effect"
design_case 0 "画面のモジュールの @Observable のクラスも、入れて取り消す Task は通る" "$sources/Features/CaseDrag.swift" $'@Observable\nfinal class CaseDrag {\n    private var armTask: Task<Void, Never>?\n\n    func arm() {\n        armTask?.cancel()\n        armTask = Task {}\n    }\n}'
plain=$'final class CaseTimer {\n    func arm() {\n        Task {}\n    }\n}'
design_case 0 "モデルを持つ View の無いモジュールの、View でも @Observable でもない型の Task は見ない" "$sources/Features/CaseTimer.swift" "$plain"
printf 'struct CaseList: View {\n    @State private var model: CaseModel\n}\n' >"$sources/Features/CaseList.swift"
design_case 2 "View がモデルを持つ画面のモジュールでは、ただのクラスの Task も止める" "$sources/Features/CaseTimer.swift" "$plain" "CaseTimer.swift:3: $effect"
design_case 2 "画面のモジュールの struct と enum の Task も止める" "$sources/Features/CaseReload.swift" $'struct CaseReload {\n    func reload() {\n        Task {}\n    }\n}\n\nprivate enum Later {\n    static func run() {\n        Task.detached {}\n    }\n}' "CaseReload.swift:9: $effect"
design_case 2 "画面のモジュールの、型の外の関数の Task も止める" "$sources/Features/CaseReload.swift" $'struct CaseReload {}\n\nfunc reload(_ model: CaseModel) {\n    Task {\n        await model.load()\n    }\n}' "CaseReload.swift:4: $effect"
design_case 2 "画面のモジュールの、View でない型を拡張するファイルの Task も止める" "$sources/Features/CaseTimer+Retry.swift" $'extension CaseTimer {\n    func retry() {\n        Task {}\n    }\n}' "CaseTimer+Retry.swift:3: $effect"
design_case 0 "画面のモジュールのただのクラスも、入れて取り消す Task は通る" "$sources/Features/CaseTimer.swift" $'final class CaseTimer {\n    private var task: Task<Void, Never>?\n\n    func arm() {\n        task?.cancel()\n        task = Task {}\n    }\n}'
design_case 0 "画面のモジュールでも、ウィジェットの TimelineProvider の Task は通る" "$sources/Features/CaseProvider.swift" $'struct CaseProvider: TimelineProvider {\n    func getTimeline(completion: @escaping (Timeline<Entry>) -> Void) {\n        Task {}\n    }\n}'
printf 'protocol CaseFeed: TimelineProvider,\n    Sendable where Entry: Sendable {}\n' >"$sources/Features/CaseFeed.swift"
design_case 0 "TimelineProvider を継ぐプロトコルを拡張するファイルの Task も通る" "$sources/Features/CaseFeed+Snapshot.swift" $'extension CaseFeed {\n    func getSnapshot(completion: @escaping (Entry) -> Void) {\n        Task {}\n    }\n}'
design_case 0 "NSObject を継ぐ委譲の型と、AppIntent の Task は通る" "$sources/Features/CaseCamera.swift" $'struct CaseCamera: UIViewControllerRepresentable {\n    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {\n        func finish() {\n            Task {}\n        }\n    }\n}\n\nprivate struct CaseCameraIntent: AppIntent {\n    func open() {\n        Task {}\n    }\n}'
design_case 0 "NSObject を継がない委譲の型の Task も通る" "$sources/Features/CasePicker.swift" $'final class CasePicker: CasePickerDelegate {\n    func pick() {\n        Task {}\n    }\n}'
rm -f "$sources/Features/CaseTimer.swift" "$sources/Features/CaseTimer+Retry.swift" "$sources/Features/CaseReload.swift"
design_case 0 "モデルのモジュールの @Observable のクラスの Task は見ない" "$sources/FeatureModels/OtherModel.swift" $'@Observable\nfinal class OtherModel {\n    func perform() {\n        Task {}\n    }\n}'
printf '@Observable\nfinal class SideModel {\n    let state: State\n}\n' >"$sources/Features/SideModel.swift"
design_case 0 "View と同じモジュールにモデルがあれば、@Observable のクラスの Task は見ない" "$sources/Features/CaseDrag.swift" "$starts"
design_case 0 "View と同じモジュールにモデルがあれば、ただのクラスの Task も見ない" "$sources/Features/CaseTimer.swift" "$plain"
design_case 2 "モデルと同じモジュールの View の Task は止める" "$sources/Features/CaseList.swift" $'struct CaseList: View {\n    func save() {\n        Task {}\n    }\n}' "CaseList.swift:3: $effect"
rm -rf "$app/ios/Packages"

gradle="$app/android"
mkdir -p "$gradle/app/src/main/kotlin/view" "$gradle/featuremodels/src/main/kotlin/model" "$gradle/app/build/generated"
touch "$gradle/app/build.gradle.kts" "$gradle/featuremodels/build.gradle.kts"
printf 'class CaseModel {\n    val input = Input()\n\n    class Input\n}\n' >"$gradle/featuremodels/src/main/kotlin/model/CaseModel.kt"
cp "$gradle/featuremodels/src/main/kotlin/model/CaseModel.kt" "$gradle/app/build/generated/CaseModel.kt"
writes=$'fun choose(model: CaseModel) {\n    model.input.count = 1\n}'
design_case 0 "Kotlin でモデルが別のモジュールにある画面は、input への代入を型に任せる" "$gradle/app/src/main/kotlin/view/CaseView.kt" "$writes"
design_case 2 "Kotlin のモデルのモジュールの中では、ほかのモデルの input への代入を止める" "$gradle/featuremodels/src/main/kotlin/model/OtherModel.kt" "$writes" "OtherModel.kt:2: モデルの input に、モデルの外から書かない"
cp "$gradle/featuremodels/src/main/kotlin/model/CaseModel.kt" "$gradle/app/src/main/kotlin/view/SideModel.kt"
design_case 2 "Kotlin で画面と同じモジュールにモデルがあれば、input への代入を止める" "$gradle/app/src/main/kotlin/view/CaseView.kt" "$writes" "CaseView.kt:2: モデルの input に、モデルの外から書かない"
rm -rf "$gradle/app" "$gradle/featuremodels"

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
check "--write-baseline は、渡していないファイルの行を残す" grep -qF "Sources/Case.swift: " "$base/.claude/code-design-baseline.txt"
printf 'struct Twice {\n    func a(at: Date = .now) {}\n}\n' >"$base/Sources/Twice.swift"
bash "$hooks" code-design-check --write-baseline "$base/Sources/Twice.swift" </dev/null >/dev/null 2>&1
printf 'struct Twice {\n    func a(at: Date = .now) {}\n    func b(at: Date = .now) {}\n}\n' >"$base/Sources/Twice.swift"
out=$(bash "$hooks" code-design-check "$base/Sources/Twice.swift" </dev/null 2>&1)
match "同じ文の外れが基準線より増えたら NG にする" "$?:$(grep -c '^NG ' <<<"$out")" "2:1"
rm "$base/Sources/Twice.swift"
out=$(bash "$hooks" code-design-check "$base/Sources/Case.swift" </dev/null 2>&1)
match "消したファイルの行が基準線に残っていたら、verify で NG にする" "$?:$(grep -c '行を消す: Sources/Twice.swift' <<<"$out")" "2:1"
printf 'struct Case {}\n' >"$base/Sources/Case.swift"
bash "$hooks" code-design-check --write-baseline "$base/Sources/Case.swift" "$base/Sources/Fine.swift" </dev/null >/dev/null 2>&1
check "外れが無くなったら、--write-baseline は基準線のファイルを消す" test ! -e "$base/.claude/code-design-baseline.txt"

finish
