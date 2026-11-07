# claude-config の確かめ方

> [!NOTE]
> claude-config を変えた時に通すコマンドと、テストの置き方が分かる。
> 名前とスクリプトの書き方は [development.md](development.md) にある。

## 🚀 動かし方

claude-config を変えたら、`make verify` を通す。

> [!IMPORTANT]
> CI は、claude-config もアプリも置かない。PR は、手元の確認を通してから作る。

| コマンド | 確かめること |
| --- | --- |
| `make verify` | `make audit` と `make test` を順に走らせる |
| `make audit` | config-audit.py で、文書と名前と書き方の決まり |
| `make test` | `tests/*.sh` の全部で、フックとスクリプトの振る舞い |
| `make test-<対象>` | `tests/<対象>.sh` の 1 本だけ |

## 🧪 テスト

テストの対象は、フックの `.py`、`scripts/` のファイル、`scripts/` を持つスキルである。テストの名前は、対象の拡張子を除いた名前にする。config-audit が、テストと対象が 1 対 1 でないと `NG` にする。

テストは `tests/<対象>.sh` に置く。

### フックのテスト

| テスト | 確かめること |
| --- | --- |
| `tests/ctx-limit-read.sh` | 大きいファイルを範囲なしで読む時だけ止めるか |
| `tests/docs-check.sh` | 文書の決まりに外れた時に止め、合う時は通すか |
| `tests/pr-gate.sh` | 確認の記録が無い時や、確認の後に変えた時に push と PR を止めるか。`--tags`・xargs・eval・`pushd`・変数の cd・`gh -R` も見るか |
| `tests/rules-detect-bash-edits.sh` | Bash と git checkout での書き換えを見つけ、make などの道具では検査の NG だけ返すか。Bash の間に Edit・Write で変えたファイルを数えないか |
| `tests/rules-require-read.sh` | 当たる rules を読む前の編集を止め、圧縮やサブエージェントでも数え違えないか。`CC_HOOKS_OFF` の名前を、run.sh と hook_io が空白・カンマ・タブ・改行で同じに分けるか |
| `tests/shell-check.sh` | `.sh` の構文と、変数の直後の全角で止めるか |
| `tests/swift-format.sh` | Mintfile に swiftformat がある時だけ走らせるか。時間切れと失敗で止めずに知らせるか |
| `tests/swift-style-check.sh` | 整形で直らない改行と空行の外れで止め、合う時は通すか。文字列とコメントの中は見ないか |

### scripts のテスト

| テスト | 確かめること |
| --- | --- |
| `tests/config-audit.sh` | わざと壊した写しで、config-audit が違反を見逃さないか |
| `tests/config-install.sh` | 一時の HOME で、入れ方がほかのフックと実体を残すか。入れた先からフックとスキルのスクリプトが動くか |
| `tests/docs-section.sh` | 見出しの一覧と節の出し方 |
| `tests/docs-tech-icons.sh` | 引数の形を確かめ、アイコンを並べた SVG を書くか |

### スキルのテスト

| テスト | 確かめること |
| --- | --- |
| `tests/app-init.sh` | ひな形の印を置き換え、一時のフォルダに新しいアプリを作れるか |
| `tests/app-plan.sh` | 通信せずに、引数の NG と通信できない時の NG を出すか |
| `tests/config-learn.sh` | フックが止めた回数を、config-learn が数えられるか |
| `tests/ctx-report.sh` | 作り物の会話の記録から、月ごとのトークンを数えられるか |
| `tests/docs-polish.sh` | 文字だけが続く節を見つけ、表・図・コードの囲みのある節は通すか |
| `tests/pr-create.sh` | ワークツリー・PR の重さ・要る確認・本文・出し方を決められるか。偽の gh と作り物のリポジトリで試す |
| `tests/pr-fix.sh` | 偽の gh で、直すものを集められるか |
| `tests/pr-prune.sh` | 偽の gh と作り物のリポジトリで、消してよいものだけを消すか。積んだブランチを main に載せ直し、ぶつかる時は残すか |
| `tests/store-release.sh` | 掲載情報の字数と形、申告の足りなさ、カスタムプロダクトページの案の誤りを、送る前に止めるか。アーカイブの失敗をログの error の行で知らせるか |
| `tests/store-reply.sh` | 通信せずに試す。引数の NG・返信済みのレビューの除外・`--dry-run` で送らないこと・送る JSON の形を確かめる |
| `tests/store-report.sh` | 通信せずに、引数の NG と売上の表の集計を出せるか。取れなかった数字を WARNING に書くか |
| `tests/ui-record.sh` | 偽の ffmpeg と偽の xcrun で、コマ数と出力先を決められ、引数の NG を出すか |
| `tests/ui-snapshot.sh` | パッケージにテストのターゲットを足せ、引数や出力先が違う時は走らせる前に NG にするか |

## 📦 テストの共通の処理

テストが共通で使う処理は、`tests/lib/` に置く。

| ファイル | 中身 |
| --- | --- |
| [tests/lib/assert.sh](../tests/lib/assert.sh) | 一時のフォルダ、`OK`・`NG` の出し方、出力が型に合うかを確かめる `match`、結果の数え方 |
| [tests/lib/fixtures.sh](../tests/lib/fixtures.sh) | 作り物のリポジトリと、偽の gh・偽のコマンド（`fake_command`） |
| [tests/lib/hooks.sh](../tests/lib/hooks.sh) | フックのテストの作り物のアプリと、フックへの入力の作り方 |
