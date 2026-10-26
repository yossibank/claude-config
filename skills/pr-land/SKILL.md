---
name: pr-land
description: マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける。PR がマージされたと分かった時や、人が片付けを頼んだ時に使う
argument-hint: "<リポジトリ> <ブランチ> <PR 番号> [...]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/land.sh *)
---

# マージの後の片付け

マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける手順。マージそのものは、この skill ではしない。

## 使い方

`$ARGUMENTS` には、PR ごとに「リポジトリ・ブランチ・PR 番号」の組を渡す。組ごとに、次を実行する。

```sh
${CLAUDE_SKILL_DIR}/scripts/land.sh <リポジトリ> <ブランチ> <PR 番号>
```

今のセッションが入っているワークツリーは、land.sh では消せない。先に `git fetch` してから、2 つを確かめる。`git diff --quiet origin/main HEAD` で中身が main と同じこと、`git status --porcelain` が空であることである。両方を満たしたら、`ExitWorktree` で消す。その後に land.sh を実行する。

## land.sh が確かめること

land.sh は、上から順に確かめる。満たさないものがあれば、`NG` の行を出して止まる。

| 確かめること | 満たさないとき |
| --- | --- |
| PR が `MERGED` か | 止まる |
| 手元が main で、未 commit の変更が無いか | 止まる |
| `pull --ff-only` の後、手元の main が `origin/main` と同じか | 止まる |
| ブランチの中身が main に入っているか | 止まり、ワークツリーとブランチを残す |
| GitHub 上にブランチが残っているか | 消さずに、`ls-remote` の結果を出す |

最後に、ワークスペースがもう無い DerivedData を消す。対象は、リポジトリとそのワークツリーの下にあったワークスペースである。消した数は `OK` の行に出す。

## 報告

land.sh が出す `OK` と `NG` の行を、リポジトリごとの表にして返す。`NG` があれば、その理由と、次にすることを書く。
