# 改善の台帳

> [!NOTE]
> claude-config の調べ直しで見つけて、まだ直していない改善と、直さないと決めたことが分かる。
> 調べ方は [config-review](../../dotclaude/skills/config-review/SKILL.md) にある。

## 📏 台帳の書き方

台帳は、残っている改善と見送ったことだけを持つ。直した改善は行を消し、経緯は git の履歴に任せる。

| 場面 | すること |
| --- | --- |
| 調べ直した | 人が選ばなかった指摘を「残っている改善」に足す。「場所」列の先頭に、リポジトリのパスをバッククォートで書く |
| PR で直した | 同じ PR で、その行を消す |
| 直さないと決めた | 「直さないと決めたこと」に、理由と一緒に移す |
| 前提が変わった | 見送りの理由が無くなったら、行を消す |
| パスが無い | 「場所」列の先頭にパスが無い行や、実在しないパスの行は、config-audit が NG にする |

## 📝 残っている改善

分類ごとに、重さの高い順に並べる。直す時は、同じ分類の行をまとめて 1 本の PR にする。

### テスト

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟡 低 | `tests/bin/config-audit.sh` | expect_audit が、呼ぶたびに全部の検査を走らせるので遅い。docs-check・pr-gate も同じ |

### 文書の読みやすさ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟡 低 | `dotclaude/rules/swift-core.md` | blankLineAfterSwitchCase と 1 行の case の決まりが合うか未検証 |

### 名前と並び

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟡 低 | `README.md` | 技術のアイコン（Bash、Git）と実行環境の表（jq）で、道具が合わない |
| 🟡 低 | `dotclaude/skills/app-init/templates/ios-app/ios/Packages/__App__App/Package.swift` | `AppFeature/` と `Features/`、`__App__App` の名前が紛らわしい |
| 🟡 低 | `lib/bin/config_install/settings.jq` | `claude-config-allow.json` の名前が役目を表さない。入れた先のファイル名なので、改名は移行が要る |
| 🟡 低 | `dotclaude/skills/app-init/templates/ios-app/docs/images/tech.svg` | docs/images/tech.svg と同じ名前で中身が違う |
| 🟡 低 | `dotclaude/output-styles/report.md`・`dotclaude/skills/store-report/`・`dotclaude/skills/ctx-report/` | `report` の名前が 3 つの物を指す |
| 🟡 低 | `dotclaude/settings.json` | swift の 2 段のフックの長い行を Edit と Write で 2 回書く |

## ⚠️ 直さないと決めたこと

調べ直しで出ても、次のものは指摘にしない。

| 中身 | 理由 |
| --- | --- |
| statusLine を足す | 人が要らないと決めた |
| `run-check.sh` の古いロックの競合を直す | mkdir と rmdir だけでは、競合を残さずに直せない |
| `make test` を並べて走らせる | 人が見送ると決めた |
| bash 5.2 で確かめる | 手元の bash が 3.2 だけで、確かめる場所が無い |
| `docs-section.sh`・`rules-detect-bash-edits.py` の改名 | 人が打つ名前なので、慣れた名前を残す |
| `make test` と `make test *` の許可の重なりを 1 つにする | 引数の無い呼び出しに `*` が当たるかを確かめられない |
| `run-check.sh`・`dotclaude/hooks/run.sh` の改名 | 参照が 30 件近くあり、変える益が小さい |
| `find-simulator.sh` の写しを 1 つにする | ひな形のアプリが単独で動くように、写しを持つ。同じかはテストで見る |
| lib の `.sh` と `.py` をフォルダで分ける | `source` のパスが 12 か所で変わり、益が小さい |
| 前置きの文を機械で止める | 要る前置きと要らない前置きを、文字だけでは分けられない |
| 「時」を使わず、ひらがなの書き方にそろえる | 「時」を止めると、「時間」「時刻」まで当たる |
| SKILL.md の手順のコマンドと allowed-tools を照らし合わせる | ずれても許可の確認が出るだけで、略した書き方の読み替えに手間がかかる |
| `dotclaude/hooks/run.sh` の、`CC_HOOKS_OFF` の知らない名前を見える所に出す | 知らない名前があってもフックが動くだけで、安全側に倒れる |
| `hash-state.sh` の `git add -A` を 1 回にする | 1 回 0.05 秒で、2 回目は確認中に入った変更を見つけるのに要る |
