---
name: pr-ship
description: 変更をブランチに切り出し、確認を通して PR を作る。人が「PR にして」「出して」など PR を作るよう頼んだ時だけ使う。自分の判断では使わない
argument-hint: "[<type>/<summary>]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/new-worktree.sh *)
---

# PR を出す

変更をブランチに切り出し、確認を通して PR を作るまでの手順。ブランチ名・commit・PR の本文の形は、`~/.claude/CLAUDE.md` の「ブランチ・コミット・PR」に従う。

## 作業場所

ブランチ名は、最初から `<type>/<summary>` にする。リポジトリによって、作り方が違う。

| 対象 | 作り方 |
| --- | --- |
| 今のセッションのリポジトリ | `EnterWorktree` の後に、`git branch -m <type>/<summary>` で名前を変える |
| ほかのリポジトリ | `${CLAUDE_SKILL_DIR}/scripts/new-worktree.sh <リポジトリ> <type>/<summary>` |

`new-worktree.sh` は、`~/.claude/worktrees/<リポジトリ名>/` の下にワークツリーを作り、そのパスを出す。形に合わないブランチ名では止まる。

## 確認

PR を作る前に、変更したリポジトリで次を通す。

- `make verify`。Makefile に無ければ、CLAUDE.md の「作業の進め方」にある確認のコマンド。CLAUDE.md が無ければ README の「動かし方」
- 変えた `.md` への `~/Applications/AI/claude-config/hooks/post-edit-check-docs.py`
- `reviewer` のエージェントに、作業場所のパスと base のブランチ名を渡して差分を見てもらう

reviewer の指摘は、直すか、直さない理由を PR の本文の「確認」に書く。

確認のログは、毎回 `mktemp` で作った新しいファイルに `>|` で書く。`mktemp` がファイルを先に作るので、`>` では zsh の noclobber で書けない。

## commit と PR

push と PR の作成の前に、人の承認を得る。示すのは、ブランチ名、commit の 1 行目、PR の本文の案、確認の結果である。人が「確認なしで出して」と頼んだ時は省く。CI を直して push し直す時は、承認を得ない。

commit と PR は、次のように作る。

- pre-commit で commit が止まったら、差分を確かめてステージし直す。`--no-verify` は使わない
- PR の本文の「確認」には、通したコマンドと、確かめていないこと（未検証）を分けて書く
- 手元では `gh pr create` を使う。クラウドのセッションでは `gh pr` が使えないので、組み込みの GitHub の道具を使う

## CI

リポジトリに `.github/workflows` があれば、PR を作ったら `gh pr checks <番号> --watch` をバックグラウンドで走らせて待つ。落ちたら原因を直し、push し直す。無ければ待たず、「確認」で通した結果で報告する。

## 報告

PR の URL、通した確認、未検証を書く。マージはしない。マージされたら `pr-land` で片付ける。
