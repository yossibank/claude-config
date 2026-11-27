#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"
source "$(dirname "$0")/../support/screen_package.sh"

export TMPDIR="$work/state/"
mkdir -p "$TMPDIR"
create="$root/dotclaude/skills/code-screen/scripts/create-screen.py"
hooks="$root/dotclaude/hooks"

# <フォルダ> <拡張子> <フック>... で、フォルダの下のファイルの全部を、アプリの make verify と同じ形で検査に通す
checked() {
    local folder=$1 suffix=$2 hook files=()
    shift 2
    while IFS= read -r -d '' file; do files+=("$file"); done < <(find "$folder" -name "*$suffix" -print0)
    for hook in "$@"; do
        python3 -I "$hooks/$hook.py" "${files[@]}" || return 1
    done
}

# <アプリ> <形> <フォルダ> [<名前>=<値>...] で、Swift のひな形を FeatureModels・Features・FeaturesTests に展開する
swift_screen() {
    local package=$1/ios/Packages/DemoApp kind=$2 folder=$3
    shift 3
    python3 -I "$create" swift "$kind" "$package/Sources/FeatureModels/$folder" "$package/Sources/Features/$folder" "$package/Tests/FeaturesTests/$folder" "$@"
}

# <アプリ> <形> <フォルダ> [<名前>=<値>...] で、Kotlin のひな形を :featuremodels と :app に展開する
kotlin_screen() {
    local android=$1/android kind=$2 folder=$3 base=kotlin/com/example/demo
    shift 3
    python3 -I "$create" kotlin "$kind" "$android/featuremodels/src/main/$base/featuremodels/$folder" "$android/app/src/main/$base/features/$folder" "$android/featuremodels/src/test/$base/featuremodels/$folder" "$@"
}

# <アプリ> <型の名前>... で、Core の型と Store の AppDatabase を持つ Android のモジュールを作る
kotlin_app() {
    local android=$1/android base=src/main/kotlin/com/example/demo name
    shift
    mkdir -p "$android/core/$base/core" "$android/store/$base/store" "$android/featuremodels" "$android/app"
    touch "$android/core/build.gradle.kts" "$android/store/build.gradle.kts" "$android/featuremodels/build.gradle.kts" "$android/app/build.gradle.kts"
    printf 'package com.example.demo.store\n\nclass AppDatabase\n' >"$android/store/$base/store/AppDatabase.kt"
    printf 'package com.example.demo.core\n\nimport com.example.demo.store.AppDatabase\n\nfun AppDatabase.stampCount(): Int = 0\n' >"$android/core/$base/core/AppDatabaseStamp.kt"
    for name in "$@"; do
        printf 'package com.example.demo.core\n\ndata class %s(\n    val name: String,\n)\n' "$name" >"$android/core/$base/core/$name.kt"
    done
}

# <アプリ> <async|sync> で、仮の Swift パッケージに、土台と一覧と編集を展開する
compiled_app() {
    local app=$1 calls=$2
    mkdir -p "$app"
    git -C "$app" init -q
    screen_package "$app" "$calls"
    swift_screen "$app" base Shared/Model || return 1
    swift_screen "$app" list Screens/Stamps Screen=StampList Item=Stamp "Database=$calls" || return 1
    swift_screen "$app" edit Screens/Stamps Screen=StampEdit Item=Stamp View=StampEditSheet "Database=$calls"
}

# <アプリ> で、展開したままのパッケージをビルドしてテストを流し、通ったら <アプリ>.ok を置く。待たずに並べて流す
swift_test() {
    { swift test --package-path "$1/ios/Packages/DemoApp" >"$1.log" 2>&1 && touch "$1.ok"; } &
}

# <アプリ> で、swift_test が通り、2 つのテストの型が走ったかを見る。落ちた時は、エラーの行を出す
swift_tested() {
    if [[ -f $1.ok ]] && grep -q 'tests in 2 suites passed' "$1.log"; then
        return 0
    fi
    grep -E 'error|failed|recorded an issue' "$1.log" || tail -5 "$1.log"
    return 1
}

app="$work/app"
mkdir -p "$app"
git -C "$app" init -q
swift="$app/ios/Packages/DemoApp"
stamps="Screens/Stamps"

expect "NG 使い方" "create-screen: 引数が足りなければ NG" python3 -I "$create" swift list "$app"
expect "NG 使い方" "create-screen: 知らない形は NG" swift_screen "$app" tab "$stamps" Screen=StampList Item=Stamp
expect "NG Screen=" "create-screen: 画面の名前が無ければ NG" swift_screen "$app" list "$stamps" Item=Stamp
expect "NG 知らない名前: Parts" "create-screen: 表に無い名前の置き換えは NG" swift_screen "$app" list "$stamps" Screen=StampList Item=Stamp Parts=AppParts
expect "NG フォルダが Sources/<ターゲット>" "create-screen: Swift のターゲットの外は NG" python3 -I "$create" swift base "$work/none" "$work/none" "$work/none"
expect "NG 土台の型か関数が無い: ScreenParts" "create-screen: Swift の土台が無ければ、画面を作らずに NG" swift_screen "$app" list "$stamps" Screen=StampList Item=Stamp
check "create-screen: NG の時は、ファイルを 1 つも置かない" test ! -e "$swift"

expect OK "create-screen: Swift の土台を作る" swift_screen "$app" base Shared/Model
check "create-screen: 口・結果・入れ物・時計をモデルのターゲットに置く" test -f "$swift/Sources/FeatureModels/Shared/Model/ScreenParts.swift"
check "create-screen: 結果を受ける modifier を画面のターゲットに置く" grep -qx 'import FeatureModels' "$swift/Sources/Features/Shared/Model/View+Outcome.swift"
expect "NG 土台の型が既にある" "create-screen: 土台がある時は、もう一度作らない" swift_screen "$app" base Shared/Model
rm "$swift/Sources/FeatureModels/Shared/Model/Shown.swift"
out=$(swift_screen "$app" base Shared/Model 2>&1)
match "create-screen: 土台の一部が無い時は、無い物だけを置く" "$?:$(grep -c '^OK' <<<"$out"):$(grep -c 'Shown.swift' <<<"$out")" "0:1:1"
expect OK "create-screen: Swift の一覧の画面を作る" swift_screen "$app" list "$stamps" Screen=StampList Item=Stamp
expect OK "create-screen: Swift の編集の画面を作る" swift_screen "$app" edit "$stamps" Screen=StampEdit Item=Stamp View=StampEditSheet
check "create-screen: モデルと画面とテストを、それぞれのフォルダに置く" test -f "$swift/Sources/FeatureModels/$stamps/StampListModel.swift" -a -f "$swift/Sources/Features/$stamps/StampListView.swift" -a -f "$swift/Tests/FeaturesTests/$stamps/StampListModelTests.swift"
check "create-screen: View= で画面の名前を変える" grep -q 'public struct StampEditSheet: View' "$swift/Sources/Features/$stamps/StampEditSheet.swift"
check "create-screen: 画面は、モデルのターゲットを import する" grep -qx 'import FeatureModels' "$swift/Sources/Features/$stamps/StampListView.swift"
check "create-screen: 画面は、DB のモジュールを import しない" test -z "$(grep -rl '^import Store' "$swift/Sources/Features")"
check "create-screen: Swift に印を残さない" test -z "$(grep -rlE '__[A-Za-z]+__' "$swift")"
expect "NG ファイルが既にある" "create-screen: 既にあるファイルは上書きしない" swift_screen "$app" list "$stamps" Screen=StampList Item=Stamp
shared="$swift/Sources/FeatureModels/$stamps"
expect "NG ファイルが既にある" "create-screen: 置くファイルどうしの名前が重なれば NG" python3 -I "$create" swift list "$shared" "$shared" "$swift/Tests/FeaturesTests/$stamps" Screen=StampTag Item=Stamp View=StampTagModel
check "create-screen: 名前が重なった時は、ファイルを 1 つも置かない" test ! -e "$shared/StampTagModel.swift"

expect OK "ひな形: Swift の土台と一覧と編集が、code-design-check と swift-style-check を通る" checked "$swift" .swift code-design-check swift-style-check
view="$swift/Sources/Features/$stamps/StampListView.swift"
replace_text "$view" "$work/broken.swift" '@State private var layout = Layout()' '@State private var isOpen = false'
cp "$work/broken.swift" "$view"
expect "View の @State に置けるのは" "ひな形: 展開した画面に外れを足すと、code-design-check が止める" checked "$swift" .swift code-design-check
replace_text "$work/broken.swift" "$view" '@State private var isOpen = false' '@State private var layout = Layout()'
replace_text "$view" "$work/broken.swift" 'model.perform {' 'Task {'
cp "$work/broken.swift" "$view"
expect "画面で Task を始めない" "ひな形: 展開した画面に Task を足すと、code-design-check が止める" checked "$swift" .swift code-design-check
replace_text "$work/broken.swift" "$view" 'Task {' 'model.perform {'
expect OK "ひな形: 外れを戻すと、また通る" checked "$swift" .swift code-design-check swift-style-check
swift_screen "$app" list Screens/Tags Screen=TagList Item=Tag >/dev/null
expect "同じ形になっている" "ひな形: 同じ形の 2 つ目を、中身を書かずに置くと、code-design-check が止める" checked "$swift" .swift code-design-check
rm -r "$swift/Sources/FeatureModels/Screens/Tags" "$swift/Sources/Features/Screens/Tags" "$swift/Tests/FeaturesTests/Screens/Tags"

kotlin_app "$app" Stamp StampDraft
android="$app/android"
models="$android/featuremodels/src/main/kotlin/com/example/demo/featuremodels"
views="$android/app/src/main/kotlin/com/example/demo/features"
expect "NG フォルダが src/<種類>/kotlin/<パッケージ>" "create-screen: Kotlin のソースの外は NG" python3 -I "$create" kotlin base "$work/none" "$work/none" "$work/none"
expect "NG 土台の型か関数が無い: ScreenClock" "create-screen: Kotlin の土台が無ければ NG" kotlin_screen "$app" list screens/stamps Screen=StampList Item=Stamp
expect OK "create-screen: Kotlin の土台を作る" kotlin_screen "$app" base shared/model
check "create-screen: パッケージを、フォルダの場所から決める" grep -qx 'package com.example.demo.featuremodels.shared.model' "$models/shared/model/ScreenOutcome.kt"
expect "NG 型か関数が無い: Tag。" "create-screen: Core の型が無ければ NG" kotlin_screen "$app" edit screens/tags Screen=TagEdit Item=Tag
expect OK "create-screen: Kotlin の一覧の画面を作る" kotlin_screen "$app" list screens/stamps Screen=StampList Item=Stamp
expect OK "create-screen: Kotlin の編集の画面を作る" kotlin_screen "$app" edit screens/stamps Screen=StampEdit Item=Stamp View=StampEditSheet
check "create-screen: 土台の import を、宣言のあるパッケージから決める" grep -qx 'import com.example.demo.featuremodels.shared.model.perform' "$views/screens/stamps/StampListView.kt"
check "create-screen: Core の型の import を、宣言のあるパッケージから決める" grep -qx 'import com.example.demo.core.StampDraft' "$models/screens/stamps/StampEditModel.kt"
check "create-screen: 拡張の関数の受け手を、型の宣言と取り違えない" grep -qx 'import com.example.demo.store.AppDatabase' "$models/screens/stamps/StampListModel.kt"
check "create-screen: 同じパッケージのモデルは、テストから import しない" test -z "$(grep -l 'import .*StampListModel$' "$android/featuremodels/src/test/kotlin/com/example/demo/featuremodels/screens/stamps/StampListModelTest.kt")"
check "create-screen: Kotlin に印を残さない" test -z "$(grep -rlE '__[A-Za-z]+__' "$android")"

expect OK "ひな形: Kotlin の土台と一覧と編集が、code-design-check と kotlin-style-check を通る" checked "$android" .kt code-design-check kotlin-style-check
view="$views/screens/stamps/StampListView.kt"
replace_text "$view" "$work/broken.kt" 'val layout = remember { Layout() }' 'var isOpen by remember { mutableStateOf(false) }'
cp "$work/broken.kt" "$view"
expect "Composable の関数で、状態を直接作らない" "ひな形: 展開した Composable に状態を足すと、code-design-check が止める" checked "$android" .kt code-design-check

named="$work/named"
mkdir -p "$named/ios/Packages/DemoApp/Sources/Features/Shared"
git -C "$named" init -q
shared="$named/ios/Packages/DemoApp/Sources/Features/Shared"
printf 'struct AppParts {}\nstruct ScreenClock {}\nprotocol Performing {}\nstruct ScreenOutcome<Value> {}\n' >"$shared/AppParts.swift"
printf 'protocol ScreenEditable {}\nstruct Shown<Value> {}\nfinal class ModelTask {}\nenum Loadable<Value> {}\nstruct ScreenWait {}\nfinal class ErrorNotice {}\n' >"$shared/ScreenEditable.swift"
printf 'import SwiftUI\n\nextension View {\n    func onOutcome() {}\n}\n' >"$shared/View+Outcome.swift"
features="$named/ios/Packages/DemoApp/Sources/Features/Screens/Stamps"
same_module() {
    python3 -I "$create" swift list "$features" "$features" "$named/ios/Packages/DemoApp/Tests/FeaturesTests/Stamps" Screen=StampList Item=Stamp "$@"
}
expect "NG 土台の型か関数が無い: ScreenParts・ScreenPerforming" "create-screen: 名前の違う土台は、渡さなければ NG" same_module
expect OK "create-screen: 土台の名前を、アプリの名前に置き換える" same_module ScreenParts=AppParts ScreenPerforming=Performing Store=Persistence
check "create-screen: 置き換えた名前で書く" grep -q 'public init(parts: AppParts)' "$features/StampListModel.swift"
check "create-screen: 既定の名前を残さない" test -z "$(grep -rlE 'ScreenParts|ScreenPerforming|import Store' "$features" "$named/ios/Packages/DemoApp/Tests")"
check "create-screen: モジュールの名前も置き換える" grep -qx 'import Persistence' "$features/StampListModel.swift"
check "create-screen: 同じターゲットのモデルは、画面から import しない" test -z "$(grep -l '^import Features$' "$features/StampListView.swift")"
check "create-screen: テストは、モデルのターゲットを import する" grep -qx 'import Features' "$named/ios/Packages/DemoApp/Tests/FeaturesTests/Stamps/StampListModelTests.swift"
expect OK "ひな形: モデルと画面が同じターゲットでも、検査を通る" checked "$features" .swift code-design-check swift-style-check

expect "NG Database= は async・sync のどちらか" "create-screen: 知らない DB の呼び方は NG" swift_screen "$app" list Screens/Notes Screen=NoteList Item=Note Database=fast
expect "NG Database=sync の版は、Swift の list と edit にだけある" "create-screen: 同期の版の土台は無いので NG" swift_screen "$work/none" base Shared/Model Database=sync
expect "NG Database=sync の版は、Swift の list と edit にだけある" "create-screen: Kotlin の同期の版は無いので NG" kotlin_screen "$app" list screens/notes Screen=NoteList Item=Stamp Database=sync
check "create-screen: DB の呼び方が NG の時は、ファイルを 1 つも置かない" test ! -e "$swift/Sources/FeatureModels/Screens/Notes" -a ! -e "$models/screens/notes"

plain="$work/plain"
mkdir -p "$plain/ios/Packages/DemoApp/Sources/FeatureModels/Shared" "$plain/ios/Packages/DemoApp/Sources/Features/Shared"
git -C "$plain" init -q
printf 'struct ScreenParts {}\nstruct ScreenClock {}\nstruct ScreenOutcome<Value> {}\n' >"$plain/ios/Packages/DemoApp/Sources/FeatureModels/Shared/ScreenParts.swift"
printf 'protocol ScreenEditable {}\nstruct Shown<Value> {}\nstruct ScreenWait {}\nfinal class ErrorNotice {}\n' >"$plain/ios/Packages/DemoApp/Sources/FeatureModels/Shared/ScreenEditable.swift"
cp "$shared/View+Outcome.swift" "$plain/ios/Packages/DemoApp/Sources/Features/Shared/View+Outcome.swift"
expect "NG 土台の型か関数が無い: ScreenPerforming" "create-screen: 非同期の版は、口が無ければ NG" swift_screen "$plain" list "$stamps" Screen=StampList Item=Stamp
expect OK "create-screen: 同期の版は、口が無くても置ける" swift_screen "$plain" list "$stamps" Screen=StampList Item=Stamp Database=sync

expect OK "create-screen: 非同期の版を、仮のパッケージに展開する" compiled_app "$work/async" async
expect OK "create-screen: 同期の版を、仮のパッケージに展開する" compiled_app "$work/sync" sync
for file in FeatureModels/$stamps/StampListModel Features/$stamps/StampListView FeatureModels/$stamps/StampEditModel Features/$stamps/StampEditSheet; do
    check "create-screen: Database=async は、渡さない時と同じ中身を置く（$(basename "$file")）" cmp -s "$work/async/ios/Packages/DemoApp/Sources/$file.swift" "$swift/Sources/$file.swift"
done
sync="$work/sync/ios/Packages/DemoApp"
check "create-screen: 同期の版は、モデルが init で読み、refresh で読み直す" test "$(grep -c 'refresh()' "$sync/Sources/FeatureModels/$stamps/StampListModel.swift")" = 3
check "create-screen: 同期の版は、async と await と perform を書かない" test -z "$(grep -rlE '\b(async|await|perform)\b' "$sync/Sources/FeatureModels/Screens" "$sync/Sources/Features/Screens" "$sync/Tests")"
check "create-screen: 同期の版の画面も、DB のモジュールを import しない" test -z "$(grep -rl '^import Store' "$sync/Sources/Features")"
check "create-screen: 同期の版に印を残さない" test -z "$(grep -rlE '__[A-Za-z]+__' "$sync")"
expect OK "ひな形: 同期の版の土台と一覧と編集が、code-design-check と swift-style-check を通る" checked "$sync" .swift code-design-check swift-style-check
model="$sync/Sources/FeatureModels/$stamps/StampListModel.swift"
cp "$model" "$work/StampListModel.swift"
replace_text "$work/StampListModel.swift" "$model" 'input.items.isEmpty' '(try? input.dependencies.database.stampList())?.isEmpty ?? true'
expect "Output" "ひな形: 同期の版の Output に DB を読ませると、code-design-check が止める" checked "$sync" .swift code-design-check
cp "$work/StampListModel.swift" "$model"

swift_test "$work/async"
swift_test "$work/sync"
wait
expect OK "ひな形: 非同期の版が、展開したままで swift build と swift test を通る" swift_tested "$work/async"
expect OK "ひな形: 同期の版が、展開したままで swift build と swift test を通る" swift_tested "$work/sync"

finish
