---
name: pr-ship
description: 変更をブランチに切り出し、確認を通して PR を作る。CI があれば結果まで見て報告する
disable-model-invocation: true
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

- CLAUDE.md の「作業の進め方」にある確認のコマンド。CLAUDE.md が無ければ README の「動かし方」
- 変えた `.md` への `~/Applications/AI/claude-config/hooks/check-docs.py`

確認のログは、毎回 `mktemp` で作った新しいファイルに書く。既存のファイルに書くと、zsh の noclobber で書けず、前回のログを読み違える。

## commit と PR

commit と PR は、次のように作る。

- pre-commit で commit が止まったら、差分を確かめてステージし直す。`--no-verify` は使わない
- PR の本文の「確認」には、通したコマンドと、確かめていないこと（未検証）を分けて書く
- 手元では `gh pr create` を使う。クラウドのセッションでは `gh pr` が使えないので、組み込みの GitHub の道具を使う

## CI

リポジトリに `.github/workflows` があれば、PR を作ったら `gh pr checks <番号> --watch` をバックグラウンドで走らせて待つ。落ちたら原因を直し、push し直す。無ければ待たず、「確認」で通した結果で報告する。

## 報告

PR の URL、通した確認、未検証を書く。マージはしない。マージされたら `/pr-land` で片付ける。
