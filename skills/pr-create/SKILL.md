---
name: pr-create
description: 変更をブランチに切り出し、差分の大きさに合わせた確認とレビューを通して PR を作る。人が「PR にして」「出して」など PR を作るよう頼んだ時だけ使う。自分の判断では使わない。
argument-hint: "[<type>/<summary>]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/*), Bash(git push *), Bash(gh pr create *), Bash(gh pr checks *)
---

# PR を作る

変更をブランチに切り出し、確認とレビューを通して PR を作る手順。ブランチ名・commit・本文の形は、共通の CLAUDE.md に従う。

## 起動条件

人が PR を作るよう頼んだ時だけ使う。CI やレビューの指摘を直す時は `pr-fix`、マージの後は `pr-prune` を使う。

## 入力

| 入力 | 中身 |
| --- | --- |
| `$ARGUMENTS` | ブランチ名 `<type>/<summary>`。省いたら変更から決める |
| base | リポジトリの既定のブランチ（`origin/HEAD`） |

## 手順

以下の `<S>` は `${CLAUDE_SKILL_DIR}/scripts` を指す。

1. 作業場所を作る。今のセッションのリポジトリなら、`EnterWorktree` の後に `git branch -m <type>/<summary>` で名前を変える。ほかのリポジトリなら `<S>/create-worktree.sh <リポジトリ> <type>/<summary>` を使い、出たパスで作業する
2. 変更を commit する
3. `<S>/classify-diff.sh <作業場所> origin/<base>` で、差分の重さと、通す確認とレビューを決める
4. 確認を `<S>/run-check.sh <作業場所> <名前> <コマンド…>` で通す。NG なら直して通し直す
5. レビューを、3 の結果に合わせて行う。指摘は直すか、直さない理由を本文に書く。直したら 4 を通し直す
6. `<S>/write-body.sh <作業場所> origin/<base> [未検証…]` で本文の枠を作る。出たファイルの要約と、変更の各行の説明を書き足す
7. 人の承認を得る。示すのは、ブランチ名、commit の 1 行目、本文、確認の結果である。人が「確認なしで出して」と頼んだ時は省く
8. `git push -u origin <ブランチ>` の後に、`<S>/route-pr.sh <作業場所> <base> <タイトル> <本文のファイル>` で出し方を決める
9. CI があれば、`gh pr checks <番号> --watch` をバックグラウンドで走らせて待つ。落ちたら `pr-fix` で直す

### 差分の重さ

`classify-diff.sh` は、変えた行の数と、変えた場所で重さを決める。

| 重さ | 条件 | 確認 | レビュー |
| --- | --- | --- | --- |
| `docs` | `.md` と `docs/` の下だけ | `make verify-docs`。無ければ、変えた `.md` への `docs-check.py` | 自分で差分を読む |
| `small` | 200 行まで | `make verify`。無ければ CLAUDE.md の確認のコマンド | `reviewer` に `model: sonnet` を付けて頼む |
| `large` | 200 行を超える。または移行・スキーマ・fixtures・プロジェクトの設定・フック・settings に触れる | `small` と同じ | `reviewer`（opus）に頼む |

reviewer には、作業場所のパスと base のブランチ名だけを渡す。

### 確認の記録

`run-check.sh` は、確認の結果を記録に残し、push と PR の作成はその記録で止める。

| 場面 | すること |
| --- | --- |
| 確認を通す | 結果を、git のフォルダの `pr-checks` に、ファイルの中身の指紋と一緒に残す |
| 記録を見る | `run-check.sh <作業場所> --status` が、NG の確認と、確認の後の変更を `NG` の行で出す |
| 本文を作る | `write-body.sh` が `--status` で確かめ、通った確認に `[x]`、未検証に `[ ]` を付ける |
| 記録を外す | 要らなくなった確認は、`run-check.sh <作業場所> --drop <名前>` で外す |
| push と PR | `hooks/pr-gate.py` が `--status` を見て、満たさなければ止める |

### 出し方

`route-pr.sh` は、gh でログインしている人の、そのリポジトリへの権限で出し方を決める。push は gh の権限ではなく、リポジトリの git の設定で通す。deploy key の `core.sshCommand` などである。

| 出力 | すること |
| --- | --- |
| `gh` | `gh pr create --base <base> --title <タイトル> --body-file <本文のファイル>` |
| `compare <URL>` | push の権限が無い。URL には題と本文が入っているので、人に渡して、ブラウザで PR を作ってもらう |

## 報告

PR の URL か、`compare` の URL を返す。あわせて、通した確認と、未検証の項目を書く。マージはしない。

## 制約

- pre-commit で commit が止まったら、差分を確かめてステージし直す。`--no-verify` は使わない
- クラウドのセッションでは `gh pr` が使えないので、組み込みの GitHub の道具を使う
- CI を直して push し直す時は、承認を得ない
