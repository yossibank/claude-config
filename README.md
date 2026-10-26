# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?logo=claude&logoColor=white)
![Python 3](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)

## 中身

ファイルごとに、読み込まれる時が違う。

| ファイル | 読み込まれる時 | 中身 |
| --- | --- | --- |
| [CLAUDE.md](CLAUDE.md) | いつも | 言語、提案と追加、不具合を直す、使う量を抑える、報告、ブランチ・コミット・PR |
| [rules/docs-writing.md](rules/docs-writing.md) | `.md` を読み書きする時 | 文書の書き方、CLAUDE.md の形 |
| [rules/code-comments.md](rules/code-comments.md) | Swift・Kotlin・設定・シェルスクリプトを読み書きする時 | コメントを書かない |
| [rules/swift-core.md](rules/swift-core.md) | Swift を読み書きする時 | 宣言の置き方、名前を付ける値、改行と空行、SwiftUI の画面、ファイルとフォルダ、テストの書き方 |
| [hooks/pre-read-guard.py](hooks/pre-read-guard.py) | Read の前 | 30KB を超えるテキストを範囲なしで読むのを止め、節や範囲を絞って読むよう返す |
| [hooks/post-edit-check-docs.py](hooks/post-edit-check-docs.py) | `.md` を Edit・Write した後。メモリのファイルは除く | `rules/docs-writing.md` のうち、文字列で分かる違反と、`docs/` の 15KB を超えるファイルを Claude に返す |
| [hooks/stop-suggest-clear.py](hooks/stop-suggest-clear.py) | 応答が終わった時と、`gh pr create` の後 | 文脈が 20 万トークンを超えるごとに 1 回と、PR を作った時に、`/ctx-handoff` で引き継ぎメモを書いて `/clear` で区切ることを勧める |
| [scripts/docs-section.sh](scripts/docs-section.sh) | 呼んだ時 | Markdown の見出しの一覧か、指定した見出しの節だけを出す |

リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

## スキル

スキルは、Claude が要る時に自分で呼ぶ。外に出す操作を含む pr-ship だけは、人が言葉で頼んだ時に呼び、push の前に承認を得る。人が `/` で呼んでもよい。

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [/ctx-handoff](skills/ctx-handoff/SKILL.md) | 人・Claude | 会話を区切る前に、続きに要ることだけを `.claude/handoff.md` に 20 行以内で書く |
| [/pr-ship](skills/pr-ship/SKILL.md) | 人が頼んだ時に Claude | 変更をブランチに切り出し、確認を通して PR を作る |
| [/pr-land](skills/pr-land/SKILL.md) | 人・Claude | マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける |
| [ui-record](skills/ui-record/SKILL.md) | Claude | iOS シミュレーターを録画し、確かめたい場面のコマだけを切り出して並べる |

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

`~/.claude` に同じ名前のファイルが無い状態で、次を実行する。

```sh
ln -s ~/Applications/AI/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/Applications/AI/claude-config/rules ~/.claude/rules
ln -s ~/Applications/AI/claude-config/agents ~/.claude/agents
```

スキルは、1 つずつ `~/.claude/skills/` にリンクする。

```sh
for s in ~/Applications/AI/claude-config/skills/*/; do ln -s "${s%/}" ~/.claude/skills/; done
```

フックは、`~/.claude/settings.json` の `hooks` に次を足して使う。

```json
"PreToolUse": [
  {
    "matcher": "Read",
    "hooks": [
      {
        "type": "command",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/pre-read-guard.py\"; [ ! -f \"$f\" ] || python3 \"$f\""
      }
    ]
  }
],
"PostToolUse": [
  {
    "matcher": "Edit|Write|MultiEdit",
    "hooks": [
      {
        "type": "command",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/post-edit-check-docs.py\"; [ ! -f \"$f\" ] || python3 \"$f\""
      }
    ]
  },
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "if": "Bash(gh pr create *)",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/stop-suggest-clear.py\"; [ ! -f \"$f\" ] || python3 \"$f\" pr"
      }
    ]
  }
],
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/stop-suggest-clear.py\"; [ ! -f \"$f\" ] || python3 \"$f\" 2>/dev/null || true"
      }
    ]
  }
]
```

手で確かめるときは、ファイルを引数に渡す。

```sh
python3 hooks/post-edit-check-docs.py README.md
```
