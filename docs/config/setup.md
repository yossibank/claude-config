# 入れ方

> [!NOTE]
> config-install.sh がすることと、`~/.claude/settings.json` への混ぜ方が分かる。
> 入れるコマンドは [README](../../README.md#-入れ方) にある。

## 🚀 入れる流れ

前提の道具は、[README の実行環境](../../README.md#-実行環境)にある。[config-install.sh](../../scripts/config-install.sh) は、次の順に進む。

```mermaid
flowchart LR
    link["~/.claude からリンクする"] --> clean["壊れたリンクを消す"]
    clean --> mix["settings.json.new を作り、差分を出す"]
    mix --> swap["差分を確かめて、mv で置き換える"]
```

各段の動きは、次のとおりである。

| 段 | 動き |
| --- | --- |
| リンクする | `dotclaude/` の中身を、settings.json を除いてリンクする。リンクでない同じ名前のファイルがあれば、`NG` を出して止まる |
| 壊れたリンクを消す | 壊れたスキルと output style のリンクを消す |
| settings.json.new を作る | [config_install.jq](../../lib/config_install.jq) で `~/.claude/settings.json` の案を作る。入れる許可の一覧は `claude-config-allow.json.new` に書く |
| 比べる | キーと配列の並びをそろえてから、今の settings.json と案を比べる。並びだけの違いは、変わらないとする |
| 置き換える | 表示された `mv` のコマンドで、2 つの `.new` を置き換える。変わらない時は、許可の一覧だけをその場で置き換える |

## 🪝 settings.json の混ぜ方

[dotclaude/settings.json](../../dotclaude/settings.json) は、混ぜるフックと許可の元である。`~/.claude/settings.json` へは、次のように混ぜる。

| 対象 | 混ぜ方 |
| --- | --- |
| 許可 | 足りないものだけを後ろに足す。前に入れて claude-config から消えた許可は外す |
| フック | `~/.claude/hooks/run.sh` を呼ぶものだけを入れ替え、ほかのフックは残す。前の形（claude-config の中を直接呼ぶもの）も外す |
| 表示 | `outputStyle` は、無い時だけ入れる |

> [!IMPORTANT]
> claude-config は `~/Applications/AI/claude-config` に置く。決まりとスキルはこの場所のスクリプトを指すので、ほかの場所から実行すると `NG` を出して止まる。

## 🔧 積んだ PR のための設定

PR を積んで出す時だけ入れる。squash でマージしても積んだ PR がぶつからないように、使う環境で次を入れる。付け替えそのものは [pr-prune](../../dotclaude/skills/pr-prune/SKILL.md) が行う。

| 対象 | 設定 | 効き目 |
| --- | --- | --- |
| GitHub（Settings → General） | 「Automatically delete head branches」を ON | マージしたブランチを消す。その上に積んだ PR の base は、既定のブランチに付け替わる |
| git | `git config --global rerere.enabled true` | 一度解いたコンフリクトの解き方を、次から使う |
| git | `git config --global rebase.updateRefs true` | 手で rebase する時に、積んだブランチをまとめて動かす |
