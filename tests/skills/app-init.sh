#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"

replace="$root/dotclaude/skills/app-init/scripts/replace-placeholders.py"
overview="$root/dotclaude/skills/app-init/templates/ios-app/docs/overview.md"
readme="$root/dotclaude/skills/app-init/templates/ios-app/README.md"
placeholder='<何のアプリかを 1 文で。誰の、どの不満を解くか>'

make_app() {
    local app=$1 summary=$2
    mkdir -p "$app/docs" "$app/ios/__App__"
    printf 'name: __App__ / __app__ / __DisplayName__\n' >"$app/ios/__App__/__App__App.swift"
    replace_text "$overview" "$app/docs/overview.md" "$placeholder" "$summary"
    cp "$readme" "$app/README.md"
}

app="$work/app"
make_app "$app" "家計を記録するアプリ。続けられない人の不満を解く。"
expect "NG 使い方" "replace-placeholders: 引数が足りなければ NG" python3 -I "$replace" "$app"
expect OK "replace-placeholders: 印を置き換える" python3 -I "$replace" "$app" Kakeibot kakeibot "カケイボ"
check "replace-placeholders: フォルダとファイルの名前の印を置き換える" test -f "$app/ios/Kakeibot/KakeibotApp.swift"
check "replace-placeholders: 中身の印を置き換える" grep -q 'name: Kakeibot / kakeibot / カケイボ' "$app/ios/Kakeibot/KakeibotApp.swift"
check "replace-placeholders: ひな形の overview の最初の 1 文を README に写す" grep -qx '家計を記録するアプリ。' "$app/README.md"
check "replace-placeholders: 冒頭の NOTE を README に写さない" test -z "$(grep -F '[!NOTE]' "$app/README.md")"

draft="$work/draft"
make_app "$draft" "$placeholder"
python3 -I "$replace" "$draft" Draft draft "下書き" >/dev/null
check "replace-placeholders: overview が書きかけなら README の印を残す" grep -q '<何のアプリかを 1 文で>' "$draft/README.md"

verify="$root/dotclaude/skills/app-init/templates/ios-app/scripts/verify.sh"
mkdir "$work/verify"
failing='printf "b.swift:1: error: x\n** BUILD FAILED **\na.swift:2: error: y\n** BUILD FAILED **\n"; exit 65'
out=$(cd "$work/verify" && bash "$verify" app-build bash -c "$failing")
match "verify: 大文字の ** BUILD FAILED ** も、順を保って重ねずに出す" "$out" $'b.swift:1: error: x\n** BUILD FAILED **\na.swift:2: error: y\nNG app-build（ログ: .build/verify/app-build.log）'
expect "NG app-build" "verify: 失敗したら NG と終了コードで返す" bash -c "cd '$work/verify' && bash '$verify' app-build bash -c '$failing'"

create="$root/dotclaude/skills/app-init/scripts/create-app.sh"
export CC_APPS_DIR="$work/apps"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
expect "NG 使い方" "create-app: 引数が足りなければ NG" bash "$create" demo
expect "NG 名前は英小文字と数字だけ" "create-app: 大文字の名前は NG" bash "$create" Demo "デモ"
expect "NG パッケージのモジュールと同じ名前" "create-app: モジュールと同じ名前は NG" bash "$create" core "コア"
expect OK "create-app: ひな形から新しいアプリを作る" bash "$create" demo "デモ"
check "create-app: 名前の印を置き換えたワークスペースがある" test -d "$CC_APPS_DIR/demo/ios/Demo.xcworkspace"
check "create-app: overview と roadmap を写す" test -f "$CC_APPS_DIR/demo/docs/roadmap.md"
check "create-app: 最初のコミットを作る" grep -q "chore: start demo" <<<"$(git -C "$CC_APPS_DIR/demo" log --oneline)"
check "create-app: 中身に印を残さない" test -z "$(git -C "$CC_APPS_DIR/demo" grep -lE '__[A-Za-z]+__')"
expect "NG docs/ のほかに中身がある" "create-app: 中身のある場所には作らない" bash "$create" demo "デモ"
mkdir -p "$CC_APPS_DIR/planned/docs"
printf '# 下書き\n' >"$CC_APPS_DIR/planned/docs/overview.md"
expect OK "create-app: app-plan の下書きがある所に作る" bash "$create" planned "下書き"
check "create-app: app-plan の下書きを上書きしない" grep -qx '# 下書き' "$CC_APPS_DIR/planned/docs/overview.md"
check "create-app: 無い方のひな形だけを写す" test -f "$CC_APPS_DIR/planned/docs/roadmap.md"
expect "NG パッケージのモジュールと同じ名前" "create-app: モデルのモジュールと同じ名前は NG" bash "$create" featuremodels "モデル"

demo="$CC_APPS_DIR/demo"
package="$demo/ios/Packages/DemoApp"
models="$package/Sources/FeatureModels"
screens="$package/Sources/Features"
template="$root/dotclaude/skills/app-init/templates/ios-app"
screen_base="$root/dotclaude/skills/code-screen/templates/swift/base"
hooks="$root/dotclaude/hooks"
export TMPDIR="$work/state/"
mkdir -p "$TMPDIR"

# <アプリ> <フック>... で、アプリの make verify と同じファイルを検査に通す
checked() {
    local app=$1 hook files=()
    shift
    while IFS= read -r file; do files+=("$app/$file"); done < <(git -C "$app" ls-files --cached --others --exclude-standard '*.swift')
    for hook in "$@"; do
        python3 -I "$hooks/$hook.py" "${files[@]}" || return 1
    done
}

# <アプリ> で、Makefile の verify が画面の import Store を止める 1 行を、そのまま走らせる
no_store() {
    local line
    line=$(grep -F 'verify.sh screens-no-store' "$1/Makefile") || return 1
    line=${line#*screens-no-store }
    (cd "$1" && eval "${line//\$\$/\$}")
}

for name in ScreenClock ScreenOutcome ScreenParts ScreenPerforming ScreenEditable Shown ModelTask Loadable; do
    check "土台: $name を、code-screen のひな形と同じ中身で置く" cmp -s "$models/Shared/Model/$name.swift" "$screen_base/model/$name.swift"
    check "土台: $name の名前が、共通の部品の一覧にある" grep -q "^| \`$name\` " "$demo/docs/architecture-parts.md"
done
check "土台: 結果を受ける modifier を、画面のターゲットに置く" grep -qx 'import FeatureModels' "$screens/Shared/Model/View+Outcome.swift"
check "土台: onOutcome の名前が、共通の部品の一覧にある" grep -q '^| `onOutcome` ' "$demo/docs/architecture-parts.md"
check "土台: 写しを、app-init のひな形に持たない" test -z "$(grep -rlE '(struct|protocol) Screen(Clock|Outcome|Parts|Performing)\b|func onOutcome' "$template" --include='*.swift')"
check "土台: 最初の commit に入れる" test -z "$(git -C "$demo" status --porcelain)"
check "create-app: 下書きがある所にも、共通の部品の一覧を置く" test -f "$CC_APPS_DIR/planned/docs/architecture-parts.md"

manifest="$package/Package.swift"
check "構成: モデルのターゲットがある" grep -q 'name: "FeatureModels"' "$manifest"
check "構成: Store に依存するのは、モデルとテストだけ" test "$(grep -c 'name: "Store"' "$manifest")" = 3
check "構成: 画面のターゲットに MemberImportVisibility を付ける" grep -q 'enableUpcomingFeature("MemberImportVisibility")' "$manifest"
check "構成: モデルを、画面と別のターゲットに置く" test -f "$models/Screens/Home/HomeModel.swift" -a -f "$screens/Screens/Home/HomeView.swift"
check "構成: モデルのテストがある" test -f "$package/Tests/FeaturesTests/Screens/Home/HomeModelTests.swift"
expect OK "構成: 画面と入口は、Store を import しない" no_store "$demo"
expect OK "ひな形: 作ったアプリが、code-design-check と swift-style-check を通る" checked "$demo" code-design-check swift-style-check

home="$screens/Screens/Home/HomeView.swift"
cp "$home" "$work/HomeView.swift"
replace_text "$work/HomeView.swift" "$home" 'import FeatureModels' $'import FeatureModels\nimport Store'
expect "import Store" "構成: 画面に import Store を足すと、verify の 1 行が止める" no_store "$demo"
replace_text "$work/HomeView.swift" "$home" 'model.perform {' 'Task {'
expect "画面で Task を始めない" "ひな形: 最初の画面に Task を足すと、code-design-check が止める" checked "$demo" code-design-check
cp "$work/HomeView.swift" "$home"

screen="$root/dotclaude/skills/code-screen/scripts/create-screen.py"
stamps="Screens/Stamps"
expect OK "code-screen: 作ったアプリに、土台を足さずに画面を足せる" python3 -I "$screen" swift list "$models/$stamps" "$screens/$stamps" "$package/Tests/FeaturesTests/$stamps" Screen=StampList Item=Stamp
expect OK "code-screen: 足した画面と最初の画面が、一緒に検査を通る" checked "$demo" code-design-check swift-style-check
expect OK "code-screen: 画面を足しても、Store を import しない" no_store "$demo"

clash="$work/clash"
make_app "$clash" "家計を記録するアプリ。"
mkdir -p "$clash/ios/Kakeibot"
expect "既にある" "replace-placeholders: 置き換えた名前が既にあれば上書きせず NG" python3 -I "$replace" "$clash" Kakeibot kakeibot "カケイボ"

finish
