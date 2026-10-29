# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?logo=claude&logoColor=white)
![Python 3.9+](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white)

## 🗺️ 全体像

フォルダは、Claude が読むものと、決まりを守らせる仕組みに分かれる。

| フォルダ | 役割 | 読み手 |
| --- | --- | --- |
| `agents/` | 任せる相手 | Claude |
| `CLAUDE.md`・`rules/` | いつも、または当たるファイルを触る時に読み込まれる決まり | Claude |
| `docs/` | アプリの共通の構成と、claude-config を直す時の決まり | 人・Claude |
| `hooks/` | 決まりを守らせるフック | 仕組み |
| `lib/` | フックとスクリプトが共通で使う処理 | 仕組み |
| `scripts/` | 入れる、検査する、文書を読むスクリプト | 人・仕組み |
| `settings/` | フックと許可の登録 | 仕組み |
| `skills/` | 手順と、手順が走らせるスクリプト | Claude |
| `tests/` | フックとスクリプトのテスト | 人・仕組み |

部品は、次のようにつながる。リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

```mermaid
flowchart LR
    install["config-install.sh"] -->|リンクする| home["~/.claude"]
    install -->|混ぜる| settings["settings.json"]
    home --> rules["CLAUDE.md・rules/"]
    home --> skills["skills/・agents/"]
    settings -->|ツールの前後で呼ぶ| run["hooks/run.sh"]
    run --> hooks["hooks/*.py"]
    skills --> scripts["skills/*/scripts/"]
    hooks --> lib["lib/"]
    scripts --> lib
```

## 🚀 入れ方

claude-config を `~/Applications/AI/claude-config` に置く。次に [config-install.sh](scripts/config-install.sh) を走らせる。

> [!NOTE]
> `jq` と Python 3.9 以上が要る。`functools.cache` などを使うので、3.9 より古い Python では動かない。

```sh
~/Applications/AI/claude-config/scripts/config-install.sh
```

### config-install.sh がすること

スクリプトは、次の順に進む。

1. CLAUDE.md・rules・agents・各スキルを `~/.claude` からリンクする。同じ名前の実体があれば `NG` を出して止まる。
2. 壊れたスキルのリンクを消す。
3. `settings/merge.jq` で `settings.json.new` を作り、差分を出す。
4. 表示された `mv` のコマンドで、差分を確かめてから置き換える。

> [!WARNING]
> フックはこの場所のファイルを読む。ほかの場所から実行すると `NG` を出して止まる。

### settings.json の混ぜ方

[settings/settings.json](settings/settings.json) は、settings.json に入れるフックと許可の元である。今の settings.json には、次のように混ぜる。

| 対象 | 混ぜ方 |
| --- | --- |
| 許可 | 足りないものだけを後ろに足す |
| フック | claude-config の `hooks/` を呼ぶものだけを入れ替え、ほかのフックは残す |

## 📚 文書

アプリを作る時と、claude-config を直す時に読む文書と、写して使うひな形である。

| 文書 | 読む時 | 中身 |
| --- | --- | --- |
| [docs/architecture-ios.md](docs/architecture-ios.md) | 構成を決める時 | iOS アプリのフォルダ、依存の向き、テスト |
| [docs/development.md](docs/development.md) | claude-config を直す時 | 名前の付け方、スクリプトの書き方、共通の処理、テスト |
| [skills/app-init/templates/ios-app/](skills/app-init/templates/ios-app/) | `app-init` の時 | 新しい iOS アプリのひな形 |
| [skills/app-plan/templates/](skills/app-plan/templates/) | `app-plan` の時 | overview と roadmap のひな形 |

## 📏 決まり

CLAUDE.md はいつも読み込まれる。rules は、当たるファイルを読み書きする時だけ読み込まれる。

| ファイル | 読み込まれる時 | 決めること |
| --- | --- | --- |
| [CLAUDE.md](CLAUDE.md) | いつも | 言語、進め方、使う量、報告、ブランチ・コミット・PR |
| [rules/code-comments.md](rules/code-comments.md) | Swift・Kotlin・設定・シェル | コメントを書かない |
| [rules/docs-app.md](rules/docs-app.md) | `docs/`・`spec/`・README・CLAUDE.md | アプリの文書ごとの役割と、足す条件 |
| [rules/docs-claude.md](rules/docs-claude.md) | CLAUDE.md・rules・SKILL.md・agents | 飾らない形と、節の並び |
| [rules/docs-human.md](rules/docs-human.md) | README・`docs/`・`spec/` | 見出しの絵文字、バッジ、README の節の順 |
| [rules/docs-writing.md](rules/docs-writing.md) | `.md` | 運用、文、表現、守らせる仕組み |
| [rules/swift-core.md](rules/swift-core.md) | Swift | 宣言の置き方、改行、空行、ファイル |
| [rules/swift-test.md](rules/swift-test.md) | `Tests/`・`<名前>Tests/` の Swift | テストの空行と型の置き方 |
| [rules/swift-ui.md](rules/swift-ui.md) | 画面と部品のフォルダ、`*View.swift` | `View` の分け方、ビューの並べ方 |

## 🪝 フック

フックは、決まりを読まずに進めた時や、確認の前に出そうとした時に止める。どれも [hooks/run.sh](hooks/run.sh) が名前で受け、`hooks/<名前>.py` を `python3 -I` で走らせる。

```mermaid
flowchart LR
    readBefore["Read の前"] --> limit["ctx-limit-read"]
    readBefore --> require["rules-require-read"]
    editBefore["Edit・Write・MultiEdit の前"] --> require
    editAfter["Edit・Write・MultiEdit の後"] --> docs["docs-check"]
    editAfter --> swift["swift-format"]
    editAfter --> shell["shell-check"]
    bashBefore["Bash の前"] --> detect["rules-detect-bash-edits"]
    bashBefore --> gate["pr-gate"]
    bashAfter["Bash の後"] --> detect
    bashAfter --> clear["ctx-suggest-clear"]
    stop["応答の終わり"] --> clear
```

| フック | 動く時 | 止める・返す時 |
| --- | --- | --- |
| [ctx-limit-read](hooks/ctx-limit-read.py) | Read の前 | 30KB を超えるテキストを、`limit` を付けずに読む時 |
| [ctx-suggest-clear](hooks/ctx-suggest-clear.py) | 応答の終わり、`gh pr create` の後 | 文脈が 20 万トークンを超える時と、PR を作った時 |
| [docs-check](hooks/docs-check.py) | Edit・Write・MultiEdit の後。メモリのファイルは見ない | `.md` が `rules/docs-*.md` に合わない時 |
| [pr-gate](hooks/pr-gate.py) | Bash の前 | pr-create の `run-check.sh` の確認の前に、push や `gh pr create` をする時 |
| [rules-detect-bash-edits](hooks/rules-detect-bash-edits.py) | Bash の前と後 | Bash でファイルを書き換えた時。git・make などは数えない |
| [rules-require-read](hooks/rules-require-read.py) | Read・Edit・Write・MultiEdit の前 | 当たる rules を、この会話でまだ読まずに編集する時 |
| [shell-check](hooks/shell-check.py) | Edit・Write・MultiEdit の後 | `.sh` の `bash -n` と、変数の直後の全角 |
| [swift-format](hooks/swift-format.py) | Edit・Write・MultiEdit の後。`.swiftformat` が無ければ動かない | `.swift` を、Mintfile の swiftformat で整える |

フックを止める時は、[環境変数](#-環境変数)の `CLAUDE_HOOKS_OFF` に名前を並べる。

```sh
CLAUDE_HOOKS_OFF="pr-gate,rules-require-read" claude
```

## 🧰 スキル

スキルは、Claude が要る時に自分で呼ぶ。人は `/<スキル>` で呼ぶ。名前の頭の分類は、[docs/development.md](docs/development.md) にある。

> [!IMPORTANT]
> pr-create と store-release は外に出す操作を含む。人が言葉で頼んだ時だけ呼び、外に出す前に承認を得る。

| 分類 | スキル | 呼ぶ人 | すること |
| --- | --- | --- | --- |
| 企画と立ち上げ | [app-init](skills/app-init/SKILL.md) | 人・Claude | ひな形から、ビルドとテストが通るアプリのリポジトリを作る |
| 企画と立ち上げ | [app-plan](skills/app-plan/SKILL.md) | 人・Claude | 競合のレビューの不満を集め、overview と roadmap の下書きを作る |
| 手入れ | [config-learn](skills/config-learn/SKILL.md) | 人・Claude | 繰り返した手直しとフックの回数から、決まりの改定案を出す |
| 文脈とトークン | [ctx-handoff](skills/ctx-handoff/SKILL.md) | 人・Claude | 区切る前に、続きに要ることを `.claude/handoff.md` に書く |
| 文脈とトークン | [ctx-report](skills/ctx-report/SKILL.md) | 人・Claude | 月ごとに、トークンを多く使った作業を表にする |
| PR | [pr-create](skills/pr-create/SKILL.md) | **人が頼んだ時だけ Claude** | 差分の大きさに合わせた確認とレビューを通して PR を作る |
| PR | [pr-fix](skills/pr-fix/SKILL.md) | 人・Claude | 落ちた CI と未解決の指摘を直し、push し直す |
| PR | [pr-prune](skills/pr-prune/SKILL.md) | 人・Claude | マージされた PR を main に反映し、ワークツリーを片付ける |
| App Store | [store-release](skills/store-release/SKILL.md) | 人が頼んだ時だけ Claude | 申告・掲載情報・スクリーンショットを確かめ、アーカイブを送る |
| App Store | [store-report](skills/store-report/SKILL.md) | 人・Claude | 全アプリの月ごとのダウンロード・収益・評価を表にする |
| 見た目と動き | [ui-record](skills/ui-record/SKILL.md) | Claude | シミュレーターを録画し、確かめたい場面のコマを並べる |
| 見た目と動き | [ui-snapshot](skills/ui-snapshot/SKILL.md) | Claude | SwiftUI の画面をテストとして描き、場合ごとの PNG にする |

## 👷 エージェント

エージェントは、仕事の重さに合わせてモデルを分ける。

| エージェント | モデル | 任せること |
| --- | --- | --- |
| [explorer](agents/explorer.md) | Haiku | 場所と事実を探して短く返す。書き換えない |
| [implementer](agents/implementer.md) | Sonnet | 方針の決まった実装、削除、名前の変更、文書の書き換え |
| [reviewer](agents/reviewer.md) | Opus | 差分を読み、マージすると困る所を 5 件まで返す |

## 🔧 環境変数

フックとスクリプトの動きは、次の環境変数で変えられる。

| 変数 | 使う所 | 中身 |
| --- | --- | --- |
| `APPS_DIR` | app-init、store-report | アプリのリポジトリの置き場所 |
| `ARCHIVE_ONLY=1` | store-release | アーカイブだけを作り、送らない |
| `ASC_ISSUER_ID` ほか `ASC_*` | store-report | App Store Connect API のキー |
| `CLAUDE_HOOKS_OFF` | hooks/run.sh、rules-detect-bash-edits | 空白・カンマ・タブで区切った名前のフックを動かさない。hooks/ に無い名前は stderr で知らせる |
| `CLAUDE_PROJECTS` | config-learn、ctx-report | 会話の記録の置き場所 |
| `DEVICE` | ui-snapshot | 描くシミュレーターの UDID |
| `EXPORT_DESTINATION=export` | store-release | 送らずに IPA を書き出す |

## 📜 スクリプト

入れる時と文書を読む時に、次のスクリプトを使う。`make verify` で走る config-audit は、[確かめ方](#-確かめ方)にある。

| スクリプト | 呼ぶ時 | すること |
| --- | --- | --- |
| [scripts/config-install.sh](scripts/config-install.sh) | 入れる時 | `~/.claude` からリンクを張り、settings.json の案を作る |
| [scripts/docs-section.sh](scripts/docs-section.sh) | 文書を読む時 | 見出しの一覧か、指定した節だけを出す |

## 🧪 確かめ方

claude-config を変えたら、`make verify` を通す。`make audit` と `make test` を順に走らせる。

```mermaid
flowchart LR
    verify["make verify"] --> audit["make audit<br/>config-audit.py"]
    audit --> test["make test<br/>tests/*.sh"]
```

| コマンド | 確かめること |
| --- | --- |
| [scripts/config-audit.py](scripts/config-audit.py) | README の表・参照先・名前と中身の食い違いと、文書とスクリプトの書き方の違反 |
| `tests/*.sh` | フックとスクリプトの振る舞い。1 本ずつの中身は [テスト](docs/development.md#-テスト) にある |
