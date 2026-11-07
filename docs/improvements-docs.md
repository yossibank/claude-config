# 台帳（文書）

> [!NOTE]
> 文書の読みやすさと、名前と並びで、まだ直していない改善が分かる。
> 書き方と、バグ・処理・テストの改善は [improvements](improvements.md) にある。

## 📝 残っている改善

分類ごとに、重さの高い順に並べる。直す時は、同じ分類の行をまとめて 1 本の PR にする。

### 文書の読みやすさ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟡 低 | `rules/swift-core.md` | blankLineAfterSwitchCase と 1 行の case の決まりが合うか未検証 |

### 名前と並び

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟡 低 | `README.md` | 技術のアイコン（Bash、Git）と実行環境の表（jq）で、道具が合わない |
| 🟡 低 | `skills/app-init/templates/ios-app/ios/Packages/__App__App/Package.swift` | `AppFeature/` と `Features/`、`__App__App` の名前が紛らわしい |
| 🟡 低 | `scripts/config-install.jq` | `claude-config-allow.json` の名前が役目を表さない。入れた先のファイル名なので、改名は移行が要る |
| 🟡 低 | `skills/app-init/templates/ios-app/docs/images/tech.svg` | docs/images/tech.svg と同じ名前で中身が違う |
| 🟡 低 | `output-styles/report.md`・`skills/store-report/`・`skills/ctx-report/` | `report` の名前が 3 つの物を指す |
| 🟡 低 | `settings/settings.json` | swift の 2 段のフックの長い行を Edit と Write で 2 回書く |
