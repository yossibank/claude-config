#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"
source "$(dirname "$0")/../support/hook_fixtures.sh"
STOP="コメントがある（rules/code-comments.md）"

comment_case() {
    local expect=$1 label=$2 path=$3 text=$4 want=
    [[ $expect != 2 ]] || want=$STOP
    hook_case code-check-comments "$expect" "$label" "$work/$path" "$text" "$want"
}

comment_case 2 "Swift の行のコメントで止める" a/A.swift $'let a = 1\n// 説明\nlet b = 2'
comment_case 2 "Swift の説明のコメントで止める" a/B.swift $'/// 説明\nstruct B {}'
comment_case 2 "Swift の行の後ろのコメントで止める" a/C.swift 'let a = 1 // 説明'
comment_case 2 "Swift の囲みのコメントで止める" a/D.swift $'/* 説明 */\nlet a = 1'
comment_case 0 "Swift の文字列の中の // は通す" a/E.swift 'let url = "https://example.com/a"'
comment_case 0 "Swift の複数行の文字列の中は通す" a/F.swift $'let text = """\n// 中身\n"""'
comment_case 0 "Package.swift の swift-tools-version は通す" a/Package.swift $'// swift-tools-version: 6.0\nimport PackageDescription'
comment_case 2 "1 行目でない swift-tools-version は止める" a/G.swift $'import Foundation\n// swift-tools-version: 6.0'
comment_case 0 "swiftlint への指定は通す" a/H.swift $'// swiftlint:disable:next force_unwrapping\nlet a = b!'
comment_case 0 "swiftformat への指定は通す" a/I.swift $'// swiftformat:disable all\nlet a = 1'

comment_case 2 "Kotlin の行のコメントで止める" a/A.kt $'val a = 1\n// 説明'
comment_case 2 "Kotlin の囲みのコメントで止める" a/B.kt $'/** 説明 */\nclass B'
comment_case 2 "Gradle の Kotlin のコメントで止める" a/build.gradle.kts $'// 説明\nplugins {}'
comment_case 0 "Kotlin の文字列の中の // は通す" a/C.kt 'val url = "https://example.com"'
comment_case 0 "ktlint への指定は通す" a/D.kt $'// ktlint-disable no-wildcard-imports\nimport a.*'

comment_case 2 "シェルの行のコメントで止める" a/a.sh $'#!/bin/bash\n# 説明\necho a'
comment_case 2 "シェルの行の後ろのコメントで止める" a/b.sh $'#!/bin/bash\necho a # 説明'
comment_case 0 "シェバンは通す" a/c.sh $'#!/bin/bash\necho a'
comment_case 0 "シェルの引数の数と配列の長さは通す" a/d.sh $'#!/bin/bash\n[[ $# -ge 1 ]] && echo "${#items[@]}"'
comment_case 0 "シェルの引用と語の中の # は通す" a/e.sh $'#!/bin/bash\necho "# a" \'# b\' c#d'
comment_case 0 "ヒアドキュメントの中の # は通す" a/f.sh $'#!/bin/bash\ncat <<EOF\n# 見出し\nEOF'
comment_case 0 "複数行の引用の中の # は通す" a/g.sh $'#!/bin/bash\necho \'a\n# b\''
comment_case 2 "\$'…' の中の \\' の後も読み続ける" a/i.sh "#!/bin/bash"$'\n'"a=\$'x\\'y'"$'\necho a <<EOF\nEOF\n# 説明'
comment_case 0 "shellcheck への指定は通す" a/h.sh $'#!/bin/bash\n# shellcheck disable=SC2086\necho $a'

comment_case 2 "Makefile のコメントで止める" a/Makefile $'# 説明\nverify:\n\techo ok'
comment_case 2 "YAML のコメントで止める" a/a.yml $'on: push\n# 説明\njobs: {}'
comment_case 2 "TOML のコメントで止める" a/a.toml $'# 説明\n[versions]'
comment_case 2 "YAML の語の中の ' を引用とみなさない" a/c.yml $'name: Don\'t stop\n# 説明'
comment_case 0 "YAML の値の中の # は通す" a/b.yaml 'run: echo "a#b" c#d'
comment_case 0 "対象でない拡張子は見ない" a/a.md $'# 見出し\n\n本文。'

printf 'let a = 1 // 説明\n' >"$work/verify.swift"
out=$(python3 -I "$root/dotclaude/hooks/code-check-comments.py" "$work/verify.swift" 2>&1)
status=$?
check "code-check-comments: verify から呼ぶ時は NG の行で止める" test "$status" = 2 -a "$(grep -c "^NG $work/verify.swift:1: コメントを消す" <<<"$out")" = 1

finish
