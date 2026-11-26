# 部品

> [!NOTE]
> claude-config の部品が、それぞれいつ動き、何をするかが分かる。
> スキルは [skills.md](skills.md)、入れ方は [setup.md](setup.md) にある。

## 📏 決まり

CLAUDE.md はいつも読み込まれる。rules は、当たるファイルを読み書きする時だけ読み込まれる。足して読む元がある rules は、元の rules と一緒に読み込まれる。

| ファイル | 読み込まれる時 | 足して読む元 | 決めること |
| --- | --- | --- | --- |
| [CLAUDE.md](../../dotclaude/CLAUDE.md) | いつも | | 言語・進め方・使う量・報告と、ブランチ・commit・PR |
| [dotclaude/output-styles/report.md](../../dotclaude/output-styles/report.md) | いつも。config-install.sh が `outputStyle` に入れる | | 結論を先に書き、表と状態の印で組む日本語の報告の形 |
| [dotclaude/rules/code-comments.md](../../dotclaude/rules/code-comments.md) | Swift・Kotlin・設定・シェル | | コメントを書かない |
| [dotclaude/rules/code-design.md](../../dotclaude/rules/code-design.md) | Swift・Kotlin | | 状態の持ち方、モデルと画面の形、重複と API の形、置き場所と検査で止める数 |
| [dotclaude/rules/docs-app.md](../../dotclaude/rules/docs-app.md) | `docs/`・`spec/`・README・CLAUDE.md | docs-core | アプリの文書ごとの役割と、足す条件 |
| [dotclaude/rules/docs-claude.md](../../dotclaude/rules/docs-claude.md) | CLAUDE.md・rules・SKILL.md・agents | docs-core | 飾らない形と、節の並び |
| [dotclaude/rules/docs-core.md](../../dotclaude/rules/docs-core.md) | `.md` | | 運用、文、表現、守らせる仕組み |
| [dotclaude/rules/docs-human.md](../../dotclaude/rules/docs-human.md) | README・`docs/`・`spec/` | docs-core | 冒頭、見出しの絵文字、技術のアイコン、README の形 |
| [dotclaude/rules/kotlin-compose.md](../../dotclaude/rules/kotlin-compose.md) | 画面と部品のフォルダ、`*View.kt` | kotlin-core | Composable の分け方、要素の並べ方 |
| [dotclaude/rules/kotlin-core.md](../../dotclaude/rules/kotlin-core.md) | Kotlin | | 宣言のまとめ方、改行、ファイル、ktlint の設定 |
| [dotclaude/rules/kotlin-layout.md](../../dotclaude/rules/kotlin-layout.md) | Kotlin | kotlin-core | ファイルとクラスの中の区画、宣言と文の空行、Composable の本体の順 |
| [dotclaude/rules/kotlin-test.md](../../dotclaude/rules/kotlin-test.md) | `src/test/`・`src/<対象>Test/` の Kotlin | kotlin-core | テストの名前と空行 |
| [dotclaude/rules/swift-core.md](../../dotclaude/rules/swift-core.md) | Swift | | プロパティのまとまり、改行、ファイル |
| [dotclaude/rules/swift-layout.md](../../dotclaude/rules/swift-layout.md) | Swift | swift-core | ファイルの区画、extension の分け方、宣言と文の空行 |
| [dotclaude/rules/swift-test.md](../../dotclaude/rules/swift-test.md) | `Tests/`・`<名前>Tests/` の Swift | swift-core | テストの空行と型の置き方 |
| [dotclaude/rules/swift-ui.md](../../dotclaude/rules/swift-ui.md) | 画面と部品のフォルダ、`*View.swift` | swift-core | `View` の分け方、ビューの並べ方 |

## 🪝 フック

フックは、決まりを守らせるために、止める・知らせる・整えるのどれかをする。どれも [run.sh](../../dotclaude/hooks/run.sh) が名前で受け、同じフォルダの `<名前>.py` を `python3 -I` で走らせる。

図の色は、表の動きの印に合わせる。赤は 🛑 止める、青は 💬 知らせる、緑は 🧹 整える。

```mermaid
flowchart LR
    readBefore["Read の前"] --> limit["ctx-limit-read"]
    readBefore -->|rules の .md だけ| require["rules-require-read"]
    editBefore["Edit・Write の前"] --> require
    editBefore --> detect["rules-detect-bash-edits"]
    editAfter["Edit・Write の後"] -->|.md だけ| docs["docs-check"]
    editAfter -->|.swift だけ| swift["swift-format"]
    swift --> swiftStyle["swift-style-check"]
    swiftStyle --> design["code-design-check"]
    design -->|.swift だけ| layout["swift-layout-check"]
    editAfter -->|.kt だけ| kotlinStyle["kotlin-style-check"]
    kotlinStyle --> design
    design -->|.kt だけ| kotlinLayout["kotlin-layout-check"]
    editAfter -->|.sh だけ| shell["shell-check"]
    editAfter --> detect
    bashBefore["Bash の前"] --> detect
    bashBefore --> gate["pr-gate"]
    bashAfter["Bash の後"] --> detect
    stop["返事を終える前"] --> japanese["reply-require-japanese"]
    toolBefore["すべての道具の前"] --> japanese

    classDef block fill:#f8d7da,stroke:#c0392b,color:#000
    classDef inform fill:#d6e9f8,stroke:#2e86c1,color:#000
    classDef tidy fill:#d5f5e3,stroke:#239b56,color:#000
    class limit,require,gate,japanese block
    class design,docs,kotlinLayout,kotlinStyle,layout,swiftStyle,shell,detect inform
    class swift tidy
```

| フック | 動き | 呼ばれる時 | 動く条件 |
| --- | --- | --- | --- |
| [code-design-check](../../dotclaude/hooks/code-design-check.py) | 💬 知らせる | `.swift` と `.kt` を Edit・Write した後。swift-style-check か kotlin-style-check の後に順に走る | `dotclaude/rules/code-design.md` の、数で分かる決まりに合わない時。大きさ・名前・状態の数・モデルの形・画面の形・同じ形を見て、アプリの基準線にある外れは通す |
| [ctx-limit-read](../../dotclaude/hooks/ctx-limit-read.py) | 🛑 止める | Read の前 | 30KB を超えるテキストを、`limit` を付けずに読む時 |
| [docs-check](../../dotclaude/hooks/docs-check.py) | 💬 知らせる | `.md` を Edit・Write した後。メモリのファイルは見ない | `.md` が `dotclaude/rules/docs-*.md` に合わない時。読みやすさの外れ（表の行の長さ、アラートの中の箇条書き、語の並べ方、大きさ）は止めずに知らせる |
| [kotlin-layout-check](../../dotclaude/hooks/kotlin-layout-check.py) | 💬 知らせる | `.kt` を Edit・Write した後。code-design-check の後に順に走る | `dotclaude/rules/kotlin-layout.md` の決まりに合わない時。区画・入れ子の深さ・空行・関数の長さ・Composable の本体の順を見て、基準線にある外れは通す |
| [kotlin-style-check](../../dotclaude/hooks/kotlin-style-check.py) | 💬 知らせる | `.kt` を Edit・Write した後 | `.kt` が、整形で直らない `dotclaude/rules/kotlin-*.md` の空行に合わない時 |
| [pr-gate](../../dotclaude/hooks/pr-gate.py) | 🛑 止める | Bash の前 | pr-create の `run-check.sh` の確認の前に、push や `gh pr create` をする時。cd と `git -C` の先が変数でも止める |
| [reply-require-japanese](../../dotclaude/hooks/reply-require-japanese.py) | 🛑 止める | 返事を終える前（Stop）と、すべての道具の前 | 返事の地の文が、コードと URL を除いて英語の時。道具の前では今のターンの一つ前の一言を見て、同じ一言では二度止めない |
| [rules-detect-bash-edits](../../dotclaude/hooks/rules-detect-bash-edits.py) | 💬 知らせる | Bash と Edit・Write の前と後 | Bash でファイルを書き換えた時。git は checkout など、gh・cd は出力の向け先だけを見て、make などの道具は NG の行だけ返す |
| [rules-require-read](../../dotclaude/hooks/rules-require-read.py) | 🛑 止める | rules の `.md` の Read と、Edit・Write の前 | 当たる rules を、この会話でまだ読まずに編集する時 |
| [shell-check](../../dotclaude/hooks/shell-check.py) | 💬 知らせる | `.sh` を Edit・Write した後 | `.sh` の `bash -n` と、変数の直後の全角 |
| [swift-format](../../dotclaude/hooks/swift-format.py) | 🧹 整える | `.swift` を Edit・Write した後。`.swiftformat` が無ければ動かない | `.swift` を、Mintfile の swiftformat で整える |
| [swift-layout-check](../../dotclaude/hooks/swift-layout-check.py) | 💬 知らせる | `.swift` を Edit・Write した後。code-design-check の後に順に走る | `dotclaude/rules/swift-layout.md` の決まりに合わない時。ファイルの区画・extension の役割・型の本体・宣言と文の空行・関数の長さを見て、アプリの基準線にある外れは通す |
| [swift-style-check](../../dotclaude/hooks/swift-style-check.py) | 💬 知らせる | `.swift` を Edit・Write した後。swift-format の後に順に走る | `.swift` が、整形で直らない `dotclaude/rules/swift-*.md` の決まりに合わない時。改行・空行・`else if` の条件の数を見る |

### 返事の言葉を見る範囲

reply-require-japanese は、会話の記録に残った一言だけを見る。道具の前に書いた一言は記録に残らないことがあり、その一言は止められない。道具の前の判定は一歩遅れるので、止めた時の文に、止めた一言の書き出しを引く。

### 例外で落ちた時

pr-gate と rules-require-read は、フック自体が落ちた時の動きが決まっている。

> [!IMPORTANT]
> pr-gate と rules-require-read は、フックが想定外の例外で落ちた時も止める。pr-gate は、run-check.sh を走らせられなかった時も止める。時間切れもこれに含む。

ほかのフックは、想定外の例外を知らせて通す。

### フックを無効にする

フックを無効にする時は、[環境変数](#-環境変数)の `CC_HOOKS_OFF` に名前を並べる。

> [!WARNING]
> `CC_HOOKS_OFF` に pr-gate を並べると、PR を出す前の確認の門も外れる。

```sh
CC_HOOKS_OFF="pr-gate,rules-require-read" claude
```

## 👷 エージェント

エージェントは、仕事の重さに合わせてモデルを分ける。

| エージェント | モデル | 呼ぶ所 | 任せること |
| --- | --- | --- | --- |
| [debugger](../../dotclaude/agents/debugger.md) | Opus | code-debug、CLAUDE.md の「任せる」 | 仮説ごとに裏付けと反証を集めて返す。書き換えない |
| [explorer](../../dotclaude/agents/explorer.md) | Haiku | CLAUDE.md の「任せる」 | 場所と事実を探して短く返す。書き換えない |
| [implementer](../../dotclaude/agents/implementer.md) | Sonnet | CLAUDE.md の「任せる」と「並べる」 | 方針の決まった実装、削除、名前の変更、文書の書き換え |
| [reviewer](../../dotclaude/agents/reviewer.md) | Opus | pr-create | 差分を読み、マージすると困る所を 5 件まで返す |
| [tester](../../dotclaude/agents/tester.md) | Sonnet | code-debug、CLAUDE.md の「任せる」 | 正常・異常・境界のテストを書いて通す。本体は直さない |

## 📜 スクリプト

入れる時、確かめる時、文書を読む時に、次のスクリプトを使う。

| スクリプト | 呼ぶ時 | すること |
| --- | --- | --- |
| [bin/config-audit.py](../../bin/config-audit.py) | `make audit` の時 | 部品の文書の表・図・参照先と名前の食い違い、置き場所、文書とスクリプトの書き方の違反を見る。引数に検査の名前を並べると、その検査だけを走らせる |
| [bin/config-install.sh](../../bin/config-install.sh) | 入れる時 | `~/.claude` からリンクを張り、settings.json の案を作る |
| [bin/docs-section.sh](../../bin/docs-section.sh) | 文書を読む時 | 見出しの一覧か、指定した節だけを出す |
| [bin/docs-color-swatches.py](../../bin/docs-color-swatches.py) | 文書にテーマの色見本を置く時 | 色の四角と名前・値を、ライトとダークの列に並べた SVG を書く |
| [bin/docs-tech-icons.py](../../bin/docs-tech-icons.py) | README の技術のアイコンを作る時 | Simple Icons のロゴを取り、アイコンを並べた SVG を書く |
| [bin/pr-merge.sh](../../bin/pr-merge.sh) | launchd が 30 分ごとに。入れる時は `install <リポジトリ>...` | PR を番号の順に squash でマージし、競合は `claude -p` に解かせて確認を通してからマージする。止めた時は、PR にコメントとラベル `auto-merge-stopped` を付け、通知を出す |

## 🔧 環境変数

フックとスクリプトの動きは、次の環境変数で変えられる。claude-config だけの変数は、`CC_` と分類で始める。表に無い `CC_` の変数と、どこも読まない行は、config-audit が `NG` にする。

| 変数 | 使う所 | 中身 |
| --- | --- | --- |
| `ASC_ISSUER_ID` ほか `ASC_*` | store-reply、store-report | App Store Connect API のキー |
| `CC_APPS_DIR` | app-init、store-reply、store-report | アプリのリポジトリの置き場所 |
| `CC_REPORTS_DIR` | store-report | 月ごとの表の置き場所 |
| `CC_HOOKS_OFF` | dotclaude/hooks/run.sh、rules-detect-bash-edits | 空白・改行・タブ・カンマで区切った名前のフックを動かさない。dotclaude/hooks/ に無い名前は stderr に出す（デバッグのログでだけ見える） |
| `CC_PROJECTS_DIR` | config-learn、ctx-report | 会話の記録の置き場所 |
| `CC_PRUNE_MIN_FREE_GB` | pr-prune | 空きがこの GB を切ったら、本体のリポジトリの DerivedData と写しも消す。既定は 20 |
| `CC_STORE_ARCHIVE_ONLY`・`CC_STORE_EXPORT` | store-release | 前の変数。付いていれば、送らずに `NG` で止まる |
| `CC_STORE_DESTINATION` | store-release | アーカイブの行き先。`upload`（既定）は送り、`export` は IPA を書き出し、`archive` はアーカイブだけを作る |
| `CC_UI_CHECK_ZONE` | ui-snapshot | 描き直して比べるタイムゾーンの名前（`UTC` など）。描いた結果が、実行する日時とタイムゾーンで変わらないかを見る |
| `CC_UI_DEVICE` | ui-snapshot | 描くシミュレーターの UDID |
| `CC_UI_WORK_DIR` | ui-snapshot | 描く時の写しを置くフォルダ。既定は `~/Library/Caches/ui-snapshot` |
