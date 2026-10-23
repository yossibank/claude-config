# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?logo=claude&logoColor=white)
![Python 3](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)

## 中身

ファイルごとに、読み込まれる時が違う。

| ファイル | 読み込まれる時 | 中身 |
| --- | --- | --- |
| [CLAUDE.md](CLAUDE.md) | いつも | 言語、提案と追加、不具合を直す、使う量を抑える、報告、ブランチ・コミット・PR |
| [rules/docs.md](rules/docs.md) | `.md` を読み書きする時 | 文書の書き方、CLAUDE.md の形 |
| [rules/comments.md](rules/comments.md) | Swift・Kotlin・設定・シェルスクリプトを読み書きする時 | コメントを書かない |
| [rules/swift.md](rules/swift.md) | Swift を読み書きする時 | 宣言の置き方、名前を付ける値、改行と空行、SwiftUI の画面、ファイルとフォルダ、テストの書き方 |
| [hooks/check-docs.py](hooks/check-docs.py) | `.md` を Edit・Write した後。メモリのファイルは除く | `rules/docs.md` のうち、文字列で分かる違反を Claude に返す |
| [hooks/suggest-clear.py](hooks/suggest-clear.py) | 応答が終わった時と、`gh pr create` の後 | 文脈が 20 万トークンを超えるごとに 1 回と、PR を作った時に、`/clear` で区切ることを勧める |

リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

## スキル

PR に関わるスキルは、`/` で名前を打ったときだけ動く。名前を `pr-` で始める。そのほかのスキルは、Claude が要るときに自分で呼ぶ。

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [/pr-ship](skills/pr-ship/SKILL.md) | 人 | 変更をブランチに切り出し、確認を通して PR を作る |
| [/pr-land](skills/pr-land/SKILL.md) | 人 | マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける |
| [sim-record](skills/sim-record/SKILL.md) | Claude | iOS シミュレーターを録画し、確かめたい場面のコマだけを切り出して並べる |

## エージェント

エージェントは、仕事の重さに合わせてモデルを分ける。

| エージェント | モデル | 任せること |
| --- | --- | --- |
| [explorer](agents/explorer.md) | Haiku | 場所と事実を探して短く返す。書き換えない |
| [implementer](agents/implementer.md) | Sonnet | 方針の決まった実装、削除、名前の変更、文書と fixtures の書き換え |

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
"PostToolUse": [
  {
    "matcher": "Edit|Write|MultiEdit",
    "hooks": [
      {
        "type": "command",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/check-docs.py\"; [ ! -f \"$f\" ] || python3 \"$f\""
      }
    ]
  },
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "if": "Bash(gh pr create *)",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/suggest-clear.py\"; [ ! -f \"$f\" ] || python3 \"$f\" pr"
      }
    ]
  }
],
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "f=\"$HOME/Applications/AI/claude-config/hooks/suggest-clear.py\"; [ ! -f \"$f\" ] || python3 \"$f\" 2>/dev/null || true"
      }
    ]
  }
]
```

手で確かめるときは、ファイルを引数に渡す。

```sh
python3 hooks/check-docs.py README.md
```
