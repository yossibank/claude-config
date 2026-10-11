# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?logo=claude&logoColor=white)
![Python 3](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)

## 中身

ファイルごとに、読み込まれる時が違う。

| ファイル | 読み込まれる時 | 中身 |
| --- | --- | --- |
| [CLAUDE.md](CLAUDE.md) | いつも | 言語、提案と追加、報告、ブランチ・コミット・PR |
| [rules/docs.md](rules/docs.md) | `.md` を読み書きする時 | 文書の書き方、CLAUDE.md の形 |
| [rules/comments.md](rules/comments.md) | Swift・Kotlin・設定・シェルスクリプトを読み書きする時 | コメントを書かない |
| [hooks/check-docs.py](hooks/check-docs.py) | `.md` を Edit・Write した後。メモリのファイルは除く | `rules/docs.md` のうち、文字列で分かる違反を Claude に返す |

リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

## スキル

スキルは、`/` で名前を打ったときだけ動く。Claude が自分の判断では呼ばない。

| スキル | すること |
| --- | --- |
| [/pr-ship](skills/pr-ship/SKILL.md) | 変更をブランチに切り出し、確認を通して PR を作る |
| [/pr-land](skills/pr-land/SKILL.md) | マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける |

PR に関わるスキルは、名前を `pr-` で始める。

## 使い方

`~/.claude` に同じ名前のファイルが無い状態で、次を実行する。

```sh
ln -s ~/Applications/AI/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/Applications/AI/claude-config/rules ~/.claude/rules
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
  }
]
```

手で確かめるときは、ファイルを引数に渡す。

```sh
python3 hooks/check-docs.py README.md
```
