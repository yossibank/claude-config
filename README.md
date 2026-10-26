# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?logo=claude&logoColor=white)
![Python 3](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)

## 中身

ファイルごとに、読み込まれる時が違う。

| ファイル | 読み込まれる時 | 中身 |
| --- | --- | --- |
| [CLAUDE.md](CLAUDE.md) | いつも | 言語、提案と追加、不具合を直す、使う量を抑える、進め方の決まり、報告、ブランチ・コミット・PR |
| [rules/docs-writing.md](rules/docs-writing.md) | `.md` を読み書きする時 | 文書の書き方、CLAUDE.md の形 |
| [rules/docs-roles.md](rules/docs-roles.md) | `.md` を読み書きする時 | アプリの文書ごとに書くこと、文書を足す条件 |
| [rules/code-comments.md](rules/code-comments.md) | Swift・Kotlin・設定・シェルスクリプトを読み書きする時 | コメントを書かない |
| [rules/swift-core.md](rules/swift-core.md) | Swift を読み書きする時 | 宣言の置き方、名前を付ける値、改行と空行、ファイルとフォルダ |
| [rules/swift-ui.md](rules/swift-ui.md) | 画面と部品のフォルダ（`AppFeature`・`AppWidget`・`DesignSystem`・`Features`）の Swift と、`*View.swift` を読み書きする時 | `View` の型の分け方、ビューの並べ方 |
| [rules/swift-test.md](rules/swift-test.md) | `Tests/`・`<名前>Tests/` の下の Swift を読み書きする時 | テストの空行、テストで使う型の置き方 |
| [docs/architecture-ios.md](docs/architecture-ios.md) | 構成を決める時に読む。自動では読み込まれない | iOS アプリのフォルダ、パッケージ、依存の向き、画面のモデル、テストの共通の形 |
| [hooks/pre-read-guard.py](hooks/pre-read-guard.py) | Read の前 | 30KB を超えるテキストを範囲なしで読むのを止め、節や範囲を絞って読むよう返す |
| [hooks/post-edit-check-docs.py](hooks/post-edit-check-docs.py) | `.md` を Edit・Write した後。メモリのファイルは除く | `rules/docs-writing.md` のうち、文字列で分かる違反と、`docs/` の 15KB を超えるファイルを Claude に返す |
| [hooks/stop-suggest-clear.py](hooks/stop-suggest-clear.py) | 応答が終わった時と、`gh pr create` の後 | 文脈が 20 万トークンを超えるごとに 1 回と、PR を作った時に、`/ctx-handoff` で引き継ぎメモを書いて `/clear` で区切ることを勧める |
| [scripts/docs-section.sh](scripts/docs-section.sh) | 呼んだ時 | Markdown の見出しの一覧か、指定した見出しの節だけを出す |
| [scripts/config-install.sh](scripts/config-install.sh) | 入れる時 | `~/.claude` からのリンクを張り、settings.json の案を作る |
| [settings/settings.json](settings/settings.json) | 入れる時 | `config-install.sh` が settings.json に入れるフックと許可 |

リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

## スキル

スキルは、Claude が要る時に自分で呼ぶ。外に出す操作を含む pr-ship だけは、人が言葉で頼んだ時に呼び、push の前に承認を得る。人が `/` で呼んでもよい。

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [/ctx-handoff](skills/ctx-handoff/SKILL.md) | 人・Claude | 会話を区切る前に、続きに要ることだけを `.claude/handoff.md` に 20 行以内で書く |
| [/pr-ship](skills/pr-ship/SKILL.md) | 人が頼んだ時に Claude | 変更をブランチに切り出し、確認を通して PR を作る |
| [/pr-land](skills/pr-land/SKILL.md) | 人・Claude | マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける |
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
| スキル | `<分類>-<動詞>` | `pr-ship`、`ui-record` |
| フック | `<イベント>-<目的>.py` | `post-edit-check-docs.py` |
| rules | `<対象>-<範囲>.md` | `swift-core.md` |
| scripts | `<分類>-<目的>.sh` | `docs-section.sh` |
| エージェント | 役割の名詞（`-er`） | `explorer` |

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

claude-config を `~/Applications/AI/claude-config` に置き、次を実行する。`jq` が要る。

```sh
~/Applications/AI/claude-config/scripts/config-install.sh
```

スクリプトは、CLAUDE.md・rules・agents・各スキルを `~/.claude` からリンクし、壊れたスキルのリンクを消す。`~/.claude` に同じ名前の実体があれば、`NG` を出して止まる。

settings.json は直接書き換えない。`settings/settings.json` の許可を足し合わせ、`hooks` を置き換えた `settings.json.new` を作り、差分を出す。claude-config に無いフックが消えていないかを確かめてから、表示された `mv` のコマンドで置き換える。

手で確かめるときは、ファイルを引数に渡す。

```sh
python3 hooks/post-edit-check-docs.py README.md
```
