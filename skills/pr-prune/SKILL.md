---
name: pr-prune
description: マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける。PR がマージされたと分かった時や、人が片付けを頼んだ時に使う。
argument-hint: "<リポジトリ> <ブランチ> <PR 番号> [...]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh *)
---

# マージの後の片付け

マージされた PR を手元の main に反映し、ワークツリーとブランチを片付ける手順。

## 入力

| 入力 | 中身 |
| --- | --- |
| `$ARGUMENTS` | PR ごとの「リポジトリ・ブランチ・PR 番号」の組 |

## 手順

片付けは、次の順に進める。

1. 今のセッションが入っているワークツリーがあれば、下の「入っているワークツリーの消し方」で先に消す。prune-merged.sh では消せない。
2. 組ごとに、prune-merged.sh を実行する。

```sh
${CLAUDE_SKILL_DIR}/scripts/prune-merged.sh <リポジトリ> <ブランチ> <PR 番号>
```

## 入っているワークツリーの消し方

今のセッションが入っているワークツリーは、次の順に消す。

1. `git fetch` する。
2. 中身が既定のブランチと同じかを、`git diff --quiet origin/<既定のブランチ> HEAD` で確かめる。
3. `git status --porcelain` が空かを確かめる。
4. 両方を満たしたら、`ExitWorktree` で消す。

## prune-merged.sh がすること

prune-merged.sh は、次の順に確かめる。満たさないものがあれば、`NG` の行を出して止まり、ワークツリーとブランチを残す。

1. `gh pr view` で PR を読めて、`MERGED` である。
2. 手元が既定のブランチで、未 commit の変更が無い。
3. `pull --ff-only` の後、手元が `origin` と同じである。
4. ブランチの中身が、既定のブランチに入っている。

GitHub 上のブランチは消さない。残っているかを `ls-remote` で見て、`OK` の行に出す。

ブランチの中身が入っているかは、次のどれかで見る。PR の head が手元に無ければ、`pull/<番号>/head` から取ってくる。

- PR の head と同じか、その祖先である
- 中身が PR の head と同じである（GitHub で付け替えられた head）
- `origin` の既定のブランチの祖先である
- 差分が、既定のブランチに入っている

最後に、ワークスペースがもう無い DerivedData を消す。対象は、リポジトリとそのワークツリーの下にあったワークスペースである。消した数は `OK` の行に出す。

## 報告

prune-merged.sh が出す `OK` と `NG` の行を、リポジトリごとの表にして返す。`NG` があれば、その理由と、次にすることを書く。

## 制約

マージそのものは、このスキルではしない。
