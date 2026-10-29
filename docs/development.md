# claude-config を直す時の決まり

> [!NOTE]
> claude-config のフック・スクリプト・スキルを足したり直したりする時の決まりが分かる。
> 名前の付け方、スクリプトの書き方、共通の処理、テストの置き場所がある。
> 使い方と入れ方は [README](../README.md) にある。

## 🏷️ 名前の付け方

名前は `<分類>-<すること>` にそろえる。フォルダの中を名前の順に並べると、分類ごとにまとまる。分類は、フォルダをまたいで同じ接頭語を使う。

| 対象 | 形 | 例 |
| --- | --- | --- |
| スキル | `<分類>-<すること>` | `pr-create`、`ctx-handoff` |
| フック | `<分類>-<すること>.py`。イベントは settings.json に書く | `docs-check.py`、`pr-gate.py` |
| rules | `<分類>-<範囲>.md` | `swift-core.md` |
| scripts | `<分類>-<すること>.sh`・`.py` | `docs-section.sh`、`config-audit.py` |
| スキルのスクリプト | 動詞を先に、`<すること>[-<対象>]` | `check-listing.py`、`create-worktree.sh` |
| エージェント | 役割の名詞（`-er`） | `explorer` |
| 環境変数 | `CC_[<分類>_]<中身>`。分類は接頭語の表の名前を大文字にする | `CC_UI_DEVICE`、`CC_APPS_DIR` |
| ひな形の印 | スクリプトが置き換える所は `__<名前>__`、人が書く所は `<中身>` | `__App__`、`<名前>` |

### 接頭語の表

分類は、次の表から選ぶ。新しい分類が要る時は、行を足してから名前を付ける。

> [!IMPORTANT]
> config-audit が、この表に無い接頭語と、使う所の違う接頭語を `NG` にする。

| 接頭語 | 分類 | 使う所 |
| --- | --- | --- |
| `app-` | 企画・立ち上げ | skills |
| `code-` | コード全般 | rules、skills |
| `config-` | claude-config 自体の手入れ | skills、scripts |
| `ctx-` | 文脈とトークンの管理 | skills、hooks |
| `docs-` | 文書 | rules、skills、hooks、scripts |
| `pr-` | PR | skills、hooks |
| `rules-` | rules を読ませる | hooks |
| `shell-` | シェルスクリプト | hooks |
| `store-` | App Store への公開と数字 | skills |
| `swift-` | Swift | rules、hooks |
| `ui-` | 見た目と動きの確認 | skills |

### 動詞の表

スキルのスクリプトの頭の動詞は、次の表から選ぶ。表に無い動詞は config-audit が `NG` にするので、行を足してから名前を付ける。

| 動詞 | すること |
| --- | --- |
| `add`・`create` | 足す、作る |
| `collect`・`fetch`・`list`・`search` | 集める、取ってくる、並べる、探す |
| `check`・`classify`・`count`・`hash` | 確かめる、分ける、数える、指紋を取る |
| `record`・`render`・`take`・`tile`・`write` | 録る、描く、撮る、並べる、書く |
| `archive`・`prune`・`replace`・`route`・`run` | アーカイブを作る、片付ける、置き換える、振り分ける、走らせる |
| `send` | 外に送る |

## 📏 スクリプトの書き方

スクリプトは、読み込まれた時に何も実行せず、結果を同じ形で返す。`make verify` の config-audit が、外れた書き方を `NG` にする。

| 対象 | 決まり |
| --- | --- |
| Python | 処理は `main()` に入れ、末尾を `if __name__ == "__main__":` にする |
| 結果 | stdout に `OK`・`NG` で始まる行で出す。失敗したら終了コード 1 で終える |
| 引数 | 足りない時は `[[ $# -ge N ]]` で確かめ、`NG` を出す。`${N:?}` は使わない |
| 知らせ | 失敗ではない知らせは stderr に出す |
| フック | 終了コード 2 で返す文は stderr に、JSON で返すものは stdout に出す |
| 共通の処理 | フックとスクリプトの共通の処理は `lib/` に置き、`sys.path.insert` で読む |
| フックの登録 | 拡張子で絞る `if` は、`Edit(//**/*.md)` と `Write(//**/*.md)` の 2 つの項目に分ける。`Edit(...)` は Write の呼び出しに当たらない |

## 📦 共通の処理

フックとスクリプトが共通で使う処理は、`lib/` に置く。

| ファイル | 使う所 | 中身 |
| --- | --- | --- |
| [lib/app_store.py](../lib/app_store.py) | app-plan・store-report・store-reply のスクリプト | App Store の検索とレビューの読み方、失敗の理由と途中までの知らせの文。App Store Connect API のキーと署名、アプリの一覧 |
| [lib/dates.py](../lib/dates.py) | 月や日時を扱うスクリプト、rules-require-read | 日本時間、月の形、記録の日時の月 |
| [lib/git.py](../lib/git.py) | フック | タイムアウト付きの git と、リポジトリの根 |
| [lib/git.sh](../lib/git.sh) | スキルの .sh、テスト | リポジトリの根（`use_repo` は無ければ NG で止まる）と、git のフォルダの中のパス（`git_file`）。既定のブランチと、GitHub での書き込みの権限 |
| [lib/hook_io.py](../lib/hook_io.py) | 各フック、collect-corrections.py、config-audit.py | 入力の JSON、コマンドの区切り、止めたフックの判定、編集する道具の名前 |
| [lib/hook_messages.py](../lib/hook_messages.py) | フック、collect-corrections.py | フックが止める時の文の書き出し。config-learn が止めた回数を数える時の目印にもなる |
| [lib/hook_state.py](../lib/hook_state.py) | フック | 状態ファイルの名前と、古い状態ファイルの掃除 |
| [lib/loader.py](../lib/loader.py) | config-audit.py、write-report.py ほか | ファイルの場所から .py を読み込む |
| [lib/md_blocks.py](../lib/md_blocks.py) | docs-check、rules-require-read、config-audit.py、collect-corrections.py | Markdown の frontmatter、見出しの下の表、コードの囲みの見分け方 |
| [lib/md_doc.py](../lib/md_doc.py) | docs-check、config-audit.py | 文書を行と種類に分けた形と、rules の表からの絵文字・README の順の読み方。`md_blocks` の上に作る |
| [lib/script_io.py](../lib/script_io.py) | スキルの .py | `NG` を出して止める `fail` と、月の引数を確かめる `require_month` |
| [lib/transcripts.py](../lib/transcripts.py) | collect-corrections.py、count-tokens.py、フック | 会話の記録の読み方 |

## 🧪 テスト

テストは `tests/<対象>.sh` に置き、`make test` で全部を走らせる。1 本だけは `make test-<対象>` で走らせる。

| テスト | 確かめること |
| --- | --- |
| `tests/app-init.sh` | ひな形の印を置き換え、一時のフォルダに新しいアプリを作れるか |
| `tests/app-plan.sh` | 通信せずに、引数の NG と通信できない時の NG を出すか |
| `tests/config-audit.sh` | わざと壊した写しで、config-audit が違反を見逃さないか |
| `tests/config-install.sh` | 一時の HOME で、入れ方がほかのフックと実体を残すか。入れた先からフックとスキルのスクリプトが動くか |
| `tests/config-learn.sh` | フックが止めた回数を、config-learn が数えられるか |
| `tests/ctx-limit-read.sh` | 大きいファイルを範囲なしで読む時だけ止めるか |
| `tests/ctx-report.sh` | 作り物の会話の記録から、月ごとのトークンを数えられるか |
| `tests/ctx-suggest-clear.sh` | 文脈が大きい時に、同じ段で 1 回だけ区切りを勧めるか |
| `tests/docs-check.sh` | 文書の決まりに外れた時に止め、合う時は通すか |
| `tests/docs-polish.sh` | 文字だけが続く節を見つけ、表・図・コードの囲みのある節は通すか |
| `tests/docs-section.sh` | 見出しの一覧と節の出し方 |
| `tests/pr-create.sh` | 作業場所・PR の重さ・本文・出し方を決められるか。偽の gh と作り物のリポジトリで試す |
| `tests/pr-fix.sh` | 偽の gh で、直すものを集められるか |
| `tests/pr-gate.sh` | 確認の記録が無い時や、確認の後に変えた時に push と PR を止めるか |
| `tests/pr-prune.sh` | 偽の gh と作り物のリポジトリで、消してよいものだけを消すか |
| `tests/rules-detect-bash-edits.sh` | Bash での書き換えを見つけ、git だけのコマンドは数えないか |
| `tests/rules-require-read.sh` | 当たる rules を読む前の編集を止め、圧縮やサブエージェントでも数え違えないか |
| `tests/shell-check.sh` | `.sh` の構文と、変数の直後の全角で止めるか |
| `tests/store-release.sh` | 掲載情報の字数と形、プライバシーの申告の足りなさを確かめられるか。アーカイブの失敗をログの error の行で知らせるか |
| `tests/store-reply.sh` | 通信せずに、引数の NG、返信済みのレビューを除くか、`--dry-run` で送らないか、送る JSON の形が正しいか |
| `tests/store-report.sh` | 通信せずに、引数の NG と売上の表の集計を出せるか。取れなかった数字を WARNING に書くか |
| `tests/swift-format.sh` | `.swiftformat` が無ければ何もしないか |
| `tests/ui-record.sh` | 偽の ffmpeg と偽の xcrun で、コマ数と出力先を決められ、引数の NG を出すか |
| `tests/ui-snapshot.sh` | パッケージにテストのターゲットを足せ、引数や出力先が違う時は走らせる前に NG にするか |

テストが共通で使う処理は、`tests/lib/` に置く。

| ファイル | 中身 |
| --- | --- |
| [tests/lib/assert.sh](../tests/lib/assert.sh) | 一時のフォルダ、`OK`・`NG` の出し方、出力が型に合うかを確かめる `match`、結果の数え方 |
| [tests/lib/fixtures.sh](../tests/lib/fixtures.sh) | 作り物のリポジトリと、偽の gh・偽のコマンド（`fake_command`） |
| [tests/lib/hooks.sh](../tests/lib/hooks.sh) | フックのテストの作り物のアプリと、フックへの入力の作り方 |
