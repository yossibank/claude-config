<div align="center">

# claude-config

Claude Code の、全リポジトリに共通の決まり。`~/.claude` からシンボリックリンクで指して使う。

</div>

## 中身

ファイルごとに、読み込まれる時が違う。

| ファイル | 読み込まれる時 | 中身 |
| --- | --- | --- |
| `CLAUDE.md` | いつも | 言語、提案と追加、報告 |
| `rules/docs.md` | `.md` を読み書きする時 | 文書の書き方、CLAUDE.md の形 |
| `rules/comments.md` | Swift・Kotlin・設定・スクリプトを読み書きする時 | コメントを書かない |

リポジトリだけの事実は、各リポジトリの CLAUDE.md と `.claude/rules/` に書く。

## 使い方

`~/.claude` に同じ名前のファイルが無い状態で、次を実行する。

```sh
ln -s ~/Applications/AI/claude-config/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/Applications/AI/claude-config/rules ~/.claude/rules
```

> [!NOTE]
> クラウドのセッション（claude.ai/code など）は `~/.claude` を読み込まない。手元の Claude Code だけで効く。
