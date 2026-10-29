---
name: pr-fix
description: 開いている PR の、落ちた CI と未解決のレビューの指摘を集めて直し、push し直す。CI が落ちた時や、人が PR の指摘への対応を頼んだ時に使う。
argument-hint: "<リポジトリ> <PR 番号>"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/*), Bash(${CLAUDE_SKILL_DIR}/../pr-create/scripts/*), Bash(git push *), Bash(gh pr checks *), Bash(gh run view *), Bash(gh api graphql *), Bash(gh pr comment *)
---

# PR の指摘を直す

開いている PR の、落ちた CI と未解決のレビューの指摘を直して push し直す手順。

## 起動条件

CI が落ちた時と、人が PR の指摘への対応を頼んだ時に使う。新しい PR は `pr-create` で作る。

## 入力

| 入力 | 中身 |
| --- | --- |
| リポジトリ | PR のブランチがあるワークツリーのパス |
| PR 番号 | 直す PR |

## 手順

PR のブランチのワークツリーで、次の順に進める。

1. `list-threads.sh` で、直すものを集める。
2. 行ごとに、直すか直さないかを決める。直さないものは理由を 1 行で書く。
3. 直して commit する。CI の失敗は、`gh run view <番号> --log-failed` で落ちた所だけを読む。
4. `pr-create` の手順の 3〜5 で、確認とレビューを通し直す。
5. `git push` する。承認は得ない。
6. 指摘への返信を書く。`ACCESS write` なら、下の「返信と解決」のコマンドで返信を投稿し、スレッドを解決する。`ACCESS read` なら、返信の案をスレッドごとに人に渡す。

`list-threads.sh` は、次の形で呼ぶ。

```sh
${CLAUDE_SKILL_DIR}/scripts/list-threads.sh <リポジトリ> <PR 番号>
```

## list-threads.sh の出力

list-threads.sh は、1 行に 1 件ずつ、次の形で出す。

| 行 | 中身 |
| --- | --- |
| `ACCESS write` | gh でログインしている人が、返信と解決をできる |
| `ACCESS read（返信と解決は人がする）` | gh でログインしている人に、書き込みの権限が無い |
| `CI NG <名前> <URL>` | 落ちた CI |
| `THREAD <ID> <ファイル>:<行> @<人>: <1 行目>` | 未解決のレビューのスレッド。行が無いときは `-` |
| `REVIEW <状態> @<人>: <1 行目> <URL>` | 本文のある、最近のレビュー |
| `COMMENT @<人>: <1 行目> <URL>` | PR の最近のコメント。対応が要るかは中身で決める |
| `NG <理由>` | gh が通らなかった。止まる |

## 返信と解決

`ACCESS write` の時だけ、PR のワークツリーで次のコマンドを使う。`<ID>` は `THREAD` の行の ID である。

```sh
gh api graphql -f id=<ID> -f body=<返信> -f query='mutation($id: ID!, $body: String!) { addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $id, body: $body}) { comment { url } } }'
gh api graphql -f id=<ID> -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
gh pr comment <PR 番号> --body-file <返信のファイル>
```

1 行目はスレッドへの返信、2 行目はスレッドの解決である。`REVIEW` と `COMMENT` の行への返信は、3 行目で PR に書く。

## 報告

スレッドとコメントごとに、直したか、直さない理由を表にして返す。`ACCESS read` の時は、返信の案も付ける。

## 制約

指摘の外の変更を混ぜない。見つけたものは、別の PR にするよう報告する。

`ACCESS read` の時は、gh で返信もスレッドの解決もしない。別のアカウントの名前で投稿されてしまう。
