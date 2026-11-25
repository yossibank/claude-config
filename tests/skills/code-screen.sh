#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"

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
    for name in "$@"; do
        printf 'package com.example.demo.core\n\ndata class %s(\n    val name: String,\n)\n' "$name" >"$android/core/$base/core/$name.kt"
    done
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
expect OK "create-screen: Swift の一覧の画面を作る" swift_screen "$app" list "$stamps" Screen=StampList Item=Stamp
expect OK "create-screen: Swift の編集の画面を作る" swift_screen "$app" edit "$stamps" Screen=StampEdit Item=Stamp View=StampEditSheet
check "create-screen: モデルと画面とテストを、それぞれのフォルダに置く" test -f "$swift/Sources/FeatureModels/$stamps/StampListModel.swift" -a -f "$swift/Sources/Features/$stamps/StampListView.swift" -a -f "$swift/Tests/FeaturesTests/$stamps/StampListModelTests.swift"
check "create-screen: View= で画面の名前を変える" grep -q 'public struct StampEditSheet: View' "$swift/Sources/Features/$stamps/StampEditSheet.swift"
check "create-screen: 画面は、モデルのターゲットを import する" grep -qx 'import FeatureModels' "$swift/Sources/Features/$stamps/StampListView.swift"
check "create-screen: 画面は、DB のモジュールを import しない" test -z "$(grep -rl '^import Store' "$swift/Sources/Features")"
check "create-screen: Swift に印を残さない" test -z "$(grep -rlE '__[A-Za-z]+__' "$swift")"
expect "NG ファイルが既にある" "create-screen: 既にあるファイルは上書きしない" swift_screen "$app" list "$stamps" Screen=StampList Item=Stamp

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

finish
