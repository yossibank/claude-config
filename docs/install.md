# 入れ方

> [!NOTE]
> config-install.sh がすることと、settings.json への混ぜ方が分かる。
> 入れるコマンドは [README](../README.md) にある。

## 🚀 入れる流れ

claude-config を `~/Applications/AI/claude-config` に置く。次に [config-install.sh](../scripts/config-install.sh) を走らせる。

> [!NOTE]
> `jq` と Python 3.9 以上が要る。`functools.cache` などを使うので、3.9 より古い Python では動かない。

スクリプトは、次の順に進む。

1. CLAUDE.md・rules・agents・スキル・output style を `~/.claude` からリンクする。同じ名前の実体があれば `NG` を出して止まる。
2. 壊れたスキルと output style のリンクを消す。
3. [config-install.jq](../scripts/config-install.jq) で `settings.json.new` を作り、差分を出す。入れる許可の一覧は `claude-config-allow.json.new` に書く。
4. 表示された `mv` のコマンドで、差分を確かめてから 2 つを置き換える。変わらない時は、許可の一覧だけをその場で置き換える。

## 🔧 settings.json の混ぜ方

[settings/settings.json](../settings/settings.json) は、settings.json に入れるフックと許可の元である。今の settings.json には、次のように混ぜる。

| 対象 | 混ぜ方 |
| --- | --- |
| 許可 | 足りないものだけを後ろに足す。前に入れて claude-config から消えた許可は外す |
| フック | claude-config の `hooks/` を呼ぶものだけを入れ替え、ほかのフックは残す |
| 表示 | `outputStyle` は、無い時だけ入れる |

> [!IMPORTANT]
> フックはこの場所のファイルを読む。ほかの場所から実行すると `NG` を出して止まる。

## 📦 積んだ PR のための設定

PR を積んで出す時だけ入れる。squash でマージしても積んだ PR がぶつからないように、使う環境で次を入れる。付け替えそのものは [pr-prune](../skills/pr-prune/SKILL.md) が行う。

| 対象 | 設定 | 効き目 |
| --- | --- | --- |
| GitHub（Settings → General） | 「Automatically delete head branches」を ON | マージしたブランチを消す。その上に積んだ PR の base は、既定のブランチに付け替わる |
| git | `git config --global rerere.enabled true` | 一度解いたコンフリクトの解き方を、次から使う |
| git | `git config --global rebase.updateRefs true` | 手で rebase する時に、積んだブランチをまとめて動かす |
