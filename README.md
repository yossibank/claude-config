# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?logo=claude&logoColor=white)
![Python 3](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)

## 中身

ファイルごとに、読み込まれる時が違う。

| ファイル | 読み込まれる時 | 中身 |
| --- | --- | --- |
| [CLAUDE.md](CLAUDE.md) | いつも | 言語、提案と追加、不具合を直す、使う量を抑える、進め方の決まり、報告、ブランチ・コミット・PR |
| [rules/docs-writing.md](rules/docs-writing.md) | `.md` を読み書きする時 | 文書の書き方、README と CLAUDE.md の形 |
| [rules/docs-app.md](rules/docs-app.md) | `docs/`・`spec/` の下と、README・CLAUDE.md を読み書きする時 | アプリの文書ごとに書くこと、文書を足す条件、decisions と画面の仕様の形 |
| [rules/code-comments.md](rules/code-comments.md) | Swift・Kotlin・設定・シェルスクリプトを読み書きする時 | コメントを書かない |
| [rules/swift-core.md](rules/swift-core.md) | Swift を読み書きする時 | 宣言の置き方、名前を付ける値、改行と空行、ファイルとフォルダ |
| [rules/swift-ui.md](rules/swift-ui.md) | 画面と部品のフォルダ（`AppFeature`・`AppWidget`・`DesignSystem`・`Features`）の Swift と、`*View.swift` を読み書きする時 | `View` の型の分け方、ビューの並べ方 |
| [rules/swift-test.md](rules/swift-test.md) | `Tests/`・`<名前>Tests/` の下の Swift を読み書きする時 | テストの空行、テストで使う型の置き方 |
| [docs/architecture-ios.md](docs/architecture-ios.md) | 構成を決める時に読む。自動では読み込まれない | iOS アプリのフォルダ、パッケージ、依存の向き、画面のモデル、テストの共通の形 |
| [templates/ios-app/](templates/ios-app/) | `app-init` の時 | 新しい iOS アプリのひな形。`__App__` などを置き換えて写す |
| [hooks/pre-edit-load-rules.py](hooks/pre-edit-load-rules.py) | Read・Edit・Write の前 | 編集するファイルに当たる rules を、この会話（圧縮の後）でまだ読んでいなければ、1 回止めて読むよう返す。Read した rules と、自動で読み込まれた rules を数える。`CLAUDE_RULES_GUARD=off` で止めない |
| [hooks/pre-bash-check-pr.py](hooks/pre-bash-check-pr.py) | `git push`・`gh pr create` の前 | pr-create の check.sh の記録が無いか、NG か、確認の後に変更があれば止める。タグの push とブランチの削除は止めない。`CLAUDE_PR_GATE=off` で止めない |
| [hooks/pre-read-guard.py](hooks/pre-read-guard.py) | Read の前 | 30KB を超えるテキストを範囲なしで読むのを止め、節や範囲を絞って読むよう返す |
| [hooks/post-edit-check-docs.py](hooks/post-edit-check-docs.py) | `.md` を Edit・Write した後。メモリのファイルは除く | `rules/docs-writing.md` のうち、文字列で分かる違反と、`docs/` の 15KB を超えるファイルを Claude に返す。HTML は README と `docs/` の下で、画像と `<details>` のタグだけを通す |
| [hooks/post-edit-format-swift.py](hooks/post-edit-format-swift.py) | `.swift` を Edit・Write した後 | git のルートに `.swiftformat` と、swiftformat を書いた `Mintfile` がある時に、`mint run swiftformat` でそのファイルを整形する。失敗は stderr に出す |
| [hooks/post-edit-check-shell.py](hooks/post-edit-check-shell.py) | `.sh` を Edit・Write した後 | `bash -n` と、bash が変数名の一部とみなす「変数の直後の全角」を Claude に返す |
| [hooks/bash-check-edits.py](hooks/bash-check-edits.py) | Bash の前と後 | Bash で書き換えたファイルを git の差で見つけ、Edit・Write を使うよう返し、当たる rules と、文書と `.sh` の検査の結果を添える。git・make などの道具の変更は数えない |
| [hooks/stop-suggest-clear.py](hooks/stop-suggest-clear.py) | 応答が終わった時と、`gh pr create` の後 | 文脈が 20 万トークンを超えるごとに 1 回と、PR を作った時に、`/ctx-handoff` で引き継ぎメモを書いて `/clear` で区切ることを勧める |
| [scripts/docs-section.sh](scripts/docs-section.sh) | 呼んだ時 | Markdown の見出しの一覧か、指定した見出しの節だけを出す |
| [scripts/config-install.sh](scripts/config-install.sh) | 入れる時 | `~/.claude` からのリンクを張り、settings.json の案を作る |
| [scripts/config-audit.py](scripts/config-audit.py) | `make verify` の時 | スキル・エージェント・rules・README・settings・スクリプト・文書の食い違いと書き方の違反を探す |
| [settings/settings.json](settings/settings.json) | 入れる時 | `config-install.sh` が settings.json に入れるフックと許可 |

リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

## スキル

スキルは、Claude が要る時に自分で呼ぶ。外に出す操作を含む pr-create と store-release は、人が言葉で頼んだ時に呼ぶ。どちらも、外に出す前に承認を得る。人が `/` で呼んでもよい。

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [/app-init](skills/app-init/SKILL.md) | 人・Claude | `templates/ios-app/` から、ビルドとテストが通る新しいアプリのリポジトリを作る |
| [/app-plan](skills/app-plan/SKILL.md) | 人・Claude | 題材から競合のレビューの不満を集め、overview と roadmap の下書きを作る |
| [/config-learn](skills/config-learn/SKILL.md) | 人・Claude | 会話の記録と feedback のメモリから、繰り返した手直しを集め、決まりの改定案を出す |
| [/ctx-handoff](skills/ctx-handoff/SKILL.md) | 人・Claude | 会話を区切る前に、続きに要ることだけを `.claude/handoff.md` に 20 行以内で書く |
| [/ctx-report](skills/ctx-report/SKILL.md) | 人・Claude | 会話の記録から、月ごとに重い作業の上位を表にする |
| [/pr-create](skills/pr-create/SKILL.md) | 人が頼んだ時に Claude | 変更をブランチに切り出し、差分の大きさに合わせた確認とレビューを通して PR を作る |
| [/pr-fix](skills/pr-fix/SKILL.md) | 人・Claude | 落ちた CI と未解決のレビューの指摘を直し、push し直す。確認には pr-create のスクリプトを使う |
| [/pr-prune](skills/pr-prune/SKILL.md) | 人・Claude | マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける |
| [/store-release](skills/store-release/SKILL.md) | 人が頼んだ時に Claude | プライバシーの申告・掲載情報・スクリーンショットを確かめ、アーカイブを App Store Connect に送る |
| [/store-report](skills/store-report/SKILL.md) | 人・Claude | 全アプリの月ごとのダウンロード・収益・評価・レビューを 1 枚の表にする |
| [ui-record](skills/ui-record/SKILL.md) | Claude | iOS シミュレーターを録画し、確かめたい場面のコマだけを切り出して並べる |
| [ui-snapshot](skills/ui-snapshot/SKILL.md) | Claude | SwiftUI の画面・部品・ウィジェットをテストとして描き、場合ごとの PNG にする。描く場合はアプリの `.claude/snapshots/` に置く |

## エージェント

エージェントは、仕事の重さに合わせてモデルを分ける。

| エージェント | モデル | 任せること |
| --- | --- | --- |
| [explorer](agents/explorer.md) | Haiku | 場所と事実を探して短く返す。書き換えない |
| [implementer](agents/implementer.md) | Sonnet | 方針の決まった実装、削除、名前の変更、文書と fixtures の書き換え |
| [reviewer](agents/reviewer.md) | Opus | 差分を読み、マージすると困る所を 5 件まで返す。書き換えない |

## 名前の付け方

似たものに同じ接頭語を付け、並び順で分類が分かるようにする。

| 対象 | 形 | 例 |
| --- | --- | --- |
| スキル | `<分類>-<すること>`。することは動詞か、作るものの名詞 | `pr-create`、`ctx-handoff` |
| フック | `<イベント>-<目的>.py`。前と後の両方で使うものは `<ツール>-<目的>.py` | `post-edit-check-docs.py`、`bash-check-edits.py` |
| rules | `<対象>-<範囲>.md` | `swift-core.md` |
| scripts | `<分類>-<目的>.sh`・`.py` | `docs-section.sh`、`config-audit.py` |
| エージェント | 役割の名詞（`-er`） | `explorer` |
| ひな形の印 | スクリプトが置き換える所は `__<名前>__`、人が書き入れる所は `<中身>` | `__App__`、`<名前>` |

スキルの分類は次から選ぶ。新しい分類が要る時は、行を足してから名前を付ける。

| 接頭語 | 分類 |
| --- | --- |
| `app-` | 企画・立ち上げ |
| `config-` | claude-config 自体の手入れ |
| `ctx-` | 文脈とトークンの管理 |
| `pr-` | PR |
| `store-` | App Store への公開と数字 |
| `ui-` | 見た目と動きの確認 |

## 使い方

claude-config を `~/Applications/AI/claude-config` に置き、次を実行する。`jq` が要る。フックはこの場所のファイルを読むので、ほかの場所から実行すると `NG` を出して止まる。フックのファイルが無い時は、フックが `NG` を出す。

```sh
~/Applications/AI/claude-config/scripts/config-install.sh
```

スクリプトは、CLAUDE.md・rules・agents・各スキルを `~/.claude` からリンクし、壊れたスキルのリンクを消す。`~/.claude` に同じ名前の実体があれば、`NG` を出して止まる。

settings.json は直接書き換えない。`settings/merge.jq` で `settings.json.new` を作り、差分を出す。許可は今の並びのまま、足りないものだけを後ろに足す。フックは claude-config の `hooks/` を呼ぶものだけを入れ替え、ほかのフックは残す。差分を確かめてから、表示された `mv` のコマンドで置き換える。

claude-config を変えたら、`make verify` を通す。`scripts/config-audit.py` が、全体の食い違いと書き方の違反を `NG` の行で出す。`tests/config-audit.sh` は、わざと壊した写しで config-audit が違反を見逃さないかを確かめる。`tests/hooks.sh` は、作り物のリポジトリと会話の記録で、フックが止めるべき時に止め、止めなくてよい時に止めないかを確かめる。
