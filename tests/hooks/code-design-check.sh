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

# --- 共通の部品の一覧 ---
shared="$app/ios/Features/Shared/Model"
design_case 0 "一覧の文書が無ければ、Shared のプロトコルを見ない" "$shared/ScreenModel.swift" 'protocol ScreenModel {}'
printf '# 共通の部品\n\n`SettingsBoardModel` を使う。\n' >"$app/docs/architecture-parts.md"
design_case 2 "一覧に無い Shared のプロトコルは止める" "$shared/ScreenModel.swift" 'protocol ScreenModel {}' "ScreenModel.swift:1: Shared に置くプロトコルは、共通の部品の一覧（docs/architecture-parts.md）に載せる: ScreenModel"
design_case 0 "一覧にある Shared のプロトコルは通る" "$shared/SettingsBoardModel.swift" 'protocol SettingsBoardModel {}'
design_case 0 "Shared の外のプロトコルは見ない" "$app/ios/Features/Screens/HomeSource.swift" 'protocol HomeSource {}'
design_case 0 "git の外のファイルは、同じ形を見ない" "$work/Second.swift" "$(body Second 20 second)"

finish
