# 改善の台帳（文書）

> [!NOTE]
> 文書の読みやすさと、名前と並びで、まだ直していない改善が分かる。
> 書き方と、バグ・処理・テストの改善は [improvements](improvements.md) にある。

## 📝 残っている改善

分類ごとに、重さの高い順に並べる。直す時は、同じ分類の行をまとめて 1 本の PR にする。

### 文書の読みやすさ

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `docs/components.md` の「フック」 | 冒頭の文が「止める」だけで、表の知らせるフックと整えるフックに合わない |
| 🟠 中 | `docs/install.md` の「入れる流れ」 | 前提の NOTE が、置く手順の文と番号付きの手順の間にある。前提を先に置く |
| 🟠 中 | `docs/architecture-ios.md` | 「make のコマンド」がフォルダの木の間にある。「動かし方」の節に出す |
| 🟠 中 | `skills/code-debug/SKILL.md` | 手順に「効かなかった変更を戻す」「直ったら 1 つずつ外す」が無い |
| 🟠 中 | `skills/store-release/SKILL.md` | PrivacyInfo のひな形のパスが途中まで。実際は `ios-app/ios/__App__/` の下にある |
| 🟠 中 | `docs/architecture-ios.md` | 「UI テストは書かない」が ui-snapshot と食い違う |
| 🟠 中 | `skills/store-release/SKILL.md` | 案の例が `APP_IPHONE_61` と `screenshots/6.3` で、本文の 6.9 インチと食い違う |
| 🟠 中 | `docs/architecture-ios.md` | TIP に kakeibot だけの写し元のパスを書いている |
| 🟠 中 | `docs/development.md` | `lib/hook_io.py` と `lib/app_store.py` の行で、1 つのセルに名詞を 6〜8 個並べる |
| 🟡 低 | `docs/architecture-ios.md` の「パッケージ」 | Kit と App の違いが 3 か所に散らばる。節の頭に比べる表を置く |
| 🟡 低 | `docs/architecture-ios.md` | `0xdead10cc` の理由をアラートにし、依存の向きを太字にする |
| 🟡 低 | `docs/install.md` の「入れる流れ」の手順 | 「実体」「2 つ」の指す先が読めない |
| 🟡 低 | `docs/components.md` のフックの表 | 列の名前の「動く時」と「当たる時」の違いが分からない |
| 🟡 低 | `docs/development.md` の表 | フックとひな形の印の行で、1 つのセルに別々の指示がある |
| 🟡 低 | `docs/development.md` | 前置きだけの文が、スクリプトの表と testing.md のテストの表の前などにある。見出しで分かるので消す |
| 🟡 低 | `agents/debugger.md` | 「未確認」と「未確定」が混ざる |
| 🟡 低 | `skills/store-report/SKILL.md` | 「上下は無い」と「Admin にする」が食い違う |
| 🟡 低 | `skills/store-release/SKILL.md` | 字数の表に、更新の説明（4000 字）が無い |
| 🟡 低 | `skills/app-init/SKILL.md` | 置き換えの印に `__Summary__` が無い。docs/architecture-ios.md が相対パスで書かれている |
| 🟡 低 | `skills/pr-create/SKILL.md` | docs-check.py の呼び方が無い |
| 🟡 低 | `skills/ui-record/SKILL.md` | 入力の節が無い |
| 🟡 低 | `agents/explorer.md` | debugger・explorer・reviewer の description に「使わない時」が無い |
| 🟡 低 | `agents/tester.md` | 「直さない」と「わざと壊して戻す」が食い違って読める |
| 🟡 低 | `rules/swift-core.md` | 空行の決まりの範囲が読み取りにくい |
| 🟡 低 | `rules/swift-ui.md` | 指す先の名前が無い |
| 🟡 低 | `output-styles/report.md` | 見出しの絵文字の扱いが、`rules/docs-claude.md` と食い違う |
| 🟡 低 | `skills/config-learn/SKILL.md` | 0 回の行の扱いが無い |
| 🟡 低 | `skills/store-reply/SKILL.md` | description の `py*` と `py *` が揺れる |
| 🟡 低 | `docs/architecture-ios.md` | spec/ の扱い、「裏に回る前の対策」「開く」の言い方が揺れる |
| 🟡 低 | `docs/testing.md` | 「CI は置かない」と「make verify を通す」が重なる |
| 🟡 低 | `skills/app-init/templates/ios-app/docs/overview.md` | 「上の表」、CLAUDE.md の「共通の形」、README の main 固定 URL が指す先を読めない |
| 🟡 低 | `docs/testing.md` | 27 行の表が 1 つ。フック・スクリプト・スキルで分ける |
| 🟡 低 | `docs/install.md` | 前提が README の実行環境と重なる。見出しの絵文字が中身に合わない |
| 🟡 低 | `README.md` | 実行環境の表に「置き場所」の行がある。技術のアイコンと表の道具が合わない |
| 🟡 低 | `docs/architecture-ios-naming.md` | 「機能の束」を定義の前に使う。テストのフォルダの置き方が読み違えられる |
| 🟡 低 | `docs/architecture-ios.md` | 型の名前を、初めに出る所で `コード` にしていない。通知の差の文が読みにくい |
| 🟡 低 | `docs/skills.md` | 「段」の列が同じ値を繰り返す。段ごとに表を分ける |
| 🟡 低 | `skills/store-report/SKILL.md` | WARNING に確かめた経緯が混ざる。store-reply も同じ |
| 🟡 低 | `skills/app-plan/SKILL.md` | 入力の節と `$ARGUMENTS` が無い |
| 🟡 低 | `skills/config-review/SKILL.md` | 使うエージェントの名前が無く、件数の上限が agents と食い違う |
| 🟡 低 | `skills/config-learn/SKILL.md` | 効き目の 4 項目を 2 つの表で重ねて書く |
| 🟡 低 | `agents/explorer.md` | debugger と explorer が CLAUDE.md と同じ文を持つ。「生成物」の指す先が無い |
| 🟡 低 | `rules/docs-claude.md` | CLAUDE.md の冒頭の 1 文の位置が 2 か所で違う |
| 🟡 低 | `skills/app-init/SKILL.md` | 置き換えの表に `__DisplayName__` の行が無い |
| 🟡 低 | `skills/pr-create/SKILL.md` | reviewer に model を付ける書き方が無く、pr-required の文が読めない。⚪ の意味が docs-human と違う |
| 🟡 低 | `rules/swift-core.md` | blankLineAfterSwitchCase と 1 行の case の決まりが合うか未検証 |
| 🟡 低 | `agents/implementer.md` | 返す長さが無い。tester も同じ |
| 🟡 低 | `skills/code-debug/SKILL.md` | CLAUDE.md の「不具合を直す」を手順の中で書き直す |

### 名前と並び

| 重さ | 場所 | 中身 |
| --- | --- | --- |
| 🟠 中 | `settings/settings.json` | 表と一覧の並べる順の決まりが無い。許可とフックも名前の順でない |
| 🟠 中 | `settings/settings.json` | Makefile に無い `make build` を許可している |
| 🟡 低 | `skills/pr-fix/scripts/list-threads.sh` | GitHub から取ってくるので、動詞は `fetch` にする |
| 🟡 低 | `tests/lib/hooks.sh` | `hooks/` と名前が重なる。`hook_fixtures.sh` にする |
| 🟡 低 | `skills/ui-snapshot/templates/screen/` | SKILL.md の呼び名の「セット」に合わせて `set/` にする |
| 🟡 低 | `scripts/` の拡張子違いの組 | `.sh` が入口でほかが中身、という決まりを書き、検査にする |
| 🟡 低 | `docs/development.md` の動詞の表 | 1 行に動詞を詰めている。`search` は外の API も呼ぶので定義と合わない |
| 🟡 低 | `docs/components.md` のスクリプトの表 | スクリプトの一覧が、`docs/development.md` の表と重なる |
| 🟡 低 | `settings/settings.json` | `make test` の許可が重なる |
| 🟡 低 | `hooks/rules-detect-bash-edits.py` | pre と post が同じ引数 `edit` で呼ばれる |
| 🟡 低 | `docs/development.md` | 接頭語 `rules-` の説明が、役目と合わない |
| 🟡 低 | `skills/app-init/templates/ios-app/ios/Packages/__App__App/Package.swift` | `AppFeature/` と `Features/`、`__App__App` の名前が紛らわしい |
| 🟡 低 | `scripts/config-install.jq` | `ours` と、`claude-config-allow.json` の名前が役目を表さない |
| 🟡 低 | `docs/improvements.md` | 「改善の台帳」と「台帳」の呼び方が揺れる |
| 🟡 低 | `docs/components.md` | 図と表で rules の並びが違う |
| 🟡 低 | `skills/app-init/templates/ios-app/docs/images/tech.svg` | docs/images/tech.svg と同じ名前で中身が違う |
| 🟡 低 | `docs/skills.md` | report が 3 つの物を指す。store-reply と store-report が一覧で混ざる |
| 🟡 低 | `settings/settings.json` | swift の 2 段のフックの長い行を Edit と Write で 2 回書く |
| 🟡 低 | `docs/development.md` | rules の名前の決まり `<分類>-<範囲>` に code-comments が合わない |
