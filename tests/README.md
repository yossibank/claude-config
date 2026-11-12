# tests

フックとスクリプトの振る舞いを確かめるテストを置く。動かし方と置き方は [testing.md](../docs/config/testing.md) にある。

## 🧪 テスト

テストは、対象の種類のフォルダに置く。名前は、対象の拡張子を除いた名前と同じである。

### フックのテスト

| テスト | 確かめること |
| --- | --- |
| [ctx-limit-read.sh](hooks/ctx-limit-read.sh) | 大きいファイルを範囲なしで読む時だけ止めるか |
| [docs-check.sh](hooks/docs-check.sh) | 文書の決まりに外れた時に止め、合う時は通すか |
| [pr-gate.sh](hooks/pr-gate.sh) | 確認の記録が無い時や、確認の後に変えた時に push と PR を止めるか |
| [reply-require-japanese.sh](hooks/reply-require-japanese.sh) | 今のターンの英語の返事だけを止め、コード・短い英語・止めた後の 2 回目は通すか |
| [rules-detect-bash-edits.sh](hooks/rules-detect-bash-edits.sh) | Bash と git checkout での書き換えを見つけ、Edit・Write で変えたファイルを数えないか |
| [rules-require-read.sh](hooks/rules-require-read.sh) | 当たる rules を読む前の編集を止め、圧縮やサブエージェントでも数え違えないか |
| [shell-check.sh](hooks/shell-check.sh) | `.sh` の構文と、変数の直後の全角で止めるか |
| [swift-format.sh](hooks/swift-format.sh) | Mintfile に swiftformat がある時だけ走らせ、失敗で止めずに知らせるか |
| [swift-style-check.sh](hooks/swift-style-check.sh) | 整形で直らない改行と空行の外れで止め、文字列とコメントの中は見ないか |

### bin のテスト

| テスト | 確かめること |
| --- | --- |
| [config-audit.sh](bin/config-audit.sh) | わざと壊した写しで、config-audit が違反を見逃さないか |
| [config-install.sh](bin/config-install.sh) | 一時の HOME で、ほかのフックと実体を残して入れられるか |
| [docs-section.sh](bin/docs-section.sh) | 見出しの一覧と節を出せるか |
| [docs-tech-icons.sh](bin/docs-tech-icons.sh) | 引数の形を確かめ、アイコンを並べた SVG を書くか |

### スキルのテスト

| テスト | 確かめること |
| --- | --- |
| [app-init.sh](skills/app-init.sh) | ひな形の印を置き換え、一時のフォルダに新しいアプリを作れるか |
| [app-plan.sh](skills/app-plan.sh) | 通信せずに、引数の NG と通信できない時の NG を出すか |
| [config-learn.sh](skills/config-learn.sh) | フックが止めた回数を数えられるか |
| [ctx-report.sh](skills/ctx-report.sh) | 作り物の会話の記録から、月ごとのトークンを数えられるか |
| [docs-polish.sh](skills/docs-polish.sh) | 文字だけが続く節を見つけ、表・図・コードの囲みのある節は通すか |
| [pr-create.sh](skills/pr-create.sh) | 偽の gh と作り物のリポジトリで、ワークツリー・重さ・確認・本文・出し方を決められるか |
| [pr-fix.sh](skills/pr-fix.sh) | 偽の gh で、直すものを集められるか |
| [pr-prune.sh](skills/pr-prune.sh) | 偽の gh と作り物のリポジトリで、消してよいものだけを消し、ぶつかる時は残すか |
| [store-release.sh](skills/store-release.sh) | 掲載情報・申告・カスタムプロダクトページの案の誤りを、送る前に止めるか |
| [store-reply.sh](skills/store-reply.sh) | 通信せずに、返信済みの除外と `--dry-run` と送る JSON の形を確かめる |
| [store-report.sh](skills/store-report.sh) | 通信せずに、売上の表の集計と、取れなかった数字の WARNING を出せるか |
| [ui-record.sh](skills/ui-record.sh) | 偽の ffmpeg と偽の xcrun で、コマ数と出力先を決められるか |
| [ui-snapshot.sh](skills/ui-snapshot.sh) | テストのターゲットを足せ、引数や出力先が違う時は走らせる前に NG にするか |

## 📦 共通の処理

テストが共通で使う処理は、[support/](support/) に置く。

| ファイル | 中身 |
| --- | --- |
| [support/assert.sh](support/assert.sh) | 一時のフォルダ、`OK`・`NG` の出し方、結果の数え方 |
| [support/fixtures.sh](support/fixtures.sh) | 作り物のリポジトリと、偽の gh・偽のコマンド |
| [support/hook_fixtures.sh](support/hook_fixtures.sh) | フックのテストの作り物のアプリと、入力の作り方 |
| [support/http_fake.sh](support/http_fake.sh) | 通信の境界を差し替える Python の部品と、偽の鍵 |
