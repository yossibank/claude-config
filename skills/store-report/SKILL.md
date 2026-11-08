---
name: store-report
description: 公開している全アプリの、月ごとのダウンロード・収益・評価・レビューを 1 枚の表にする。月の初めに前の月の数字を見る時や、人がアプリの数字を聞いた時に使う。
argument-hint: "<YYYY-MM>"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/*), Bash(python3 -I ${CLAUDE_SKILL_DIR}/../app-plan/scripts/*)
---

# アプリの数字をまとめる

公開している全アプリの数字を、月ごとの表にまとめる手順。月の初めに、前の月の分を作る。月の途中なら、前の日までの分を作る。

## 入力

引数は、まとめる月の `<YYYY-MM>` である。集めるアプリと表の置き場所は、次のとおりである。アプリの置き場所は `CC_APPS_DIR`、表の置き場所は `CC_REPORTS_DIR` で変えられる。

| 読むもの・書くもの | 場所 |
| --- | --- |
| 集めるアプリ | `~/Applications/AppStore/*/store/app-id.txt` を持つもの。中身は App Store の ID（数字）だけ |
| 表 | `~/Applications/AppReport/<YYYY-MM>.md` |

## 手順

1. `write-report.py` で表を作る。
2. 星 2 以下のレビューが増えたアプリは、中身を読んで不満を 3 つまでにまとめる。読むには、`app-plan` の `fetch-rival-reviews.py` に自分のアプリの ID を渡す。
3. `store/custom-pages.json` を持つアプリがあれば、「カスタムプロダクトページの比べ方」で比べる。
4. 表と、前の月から大きく変わった所と、2 の不満と、3 の比べた結果を報告する。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/write-report.py <YYYY-MM>
python3 -I ${CLAUDE_SKILL_DIR}/../app-plan/scripts/fetch-rival-reviews.py <アプリの ID> [星の上限]
```

このスキルは、`app-plan` のスクリプトに依存する。`app-plan` は競合のレビューを取るが、ここでは自分のアプリのレビューを取る。

## write-report.py の出力

`write-report.py` が書く表の列は、次のとおりである。

| 列 | 出どころ | 要るもの |
| --- | --- | --- |
| ダウンロード | 売上のレポート。新規のダウンロードだけを数え、更新は数えない | API のキー |
| 収益 | 売上のレポートの手取り。通貨ごとに足す | API のキー |
| 評価、評価の数 | 日本の App Store の公開の情報 | なし |
| 今月のレビュー、星 2 以下 | 日本の App Store の公開のレビュー。新しい順に 500 件まで | なし |

取れなかった列は `—` にし、理由を表の下の WARNING に書く。

月のレポートがまだ無い月は、日ごとのレポートを月の初めから前の日まで足す。足した時は、読んだ最後の日とレポートのあった日数を WARNING に書く。

## API のキー

売上のレポートは、App Store Connect API から取る。次の環境変数を、`~/.zshenv` などで渡す。

| 環境変数 | 中身 |
| --- | --- |
| `ASC_ISSUER_ID` | キーの Issuer ID |
| `ASC_KEY_ID` | キーの ID |
| `ASC_KEY_PATH` | `.p8` のファイルのパス |
| `ASC_VENDOR_NUMBER` | 「支払いと財務レポート」にあるベンダー番号 |

キーは、App Store Connect の「ユーザとアクセス」で作る。要る役割は、スキルごとに次のとおりである。

| スキル | 要る役割 |
| --- | --- |
| store-report | 財務 |
| store-reply | カスタマーサポート |
| store-release の `create-custom-pages.py` | App マネージャ |

いくつかのスキルで使う時は、要る役割をすべて付けるか、Admin にする。

## カスタムプロダクトページの比べ方

`store/custom-pages.json` を持つアプリは、次の順で比べる。

1. App Analytics の「獲得」→「カスタムプロダクトページ」を開く。ページごとの表示・ダウンロード・ダウンロードの割合を比べる。
2. 割合の低いページは、`custom-pages.json` の先頭の画像か宣伝文を入れ替える案を出す。

初めてのダウンロードが 5 件に届かないページは、数字が出ない。その時は、比べずに見送ったと書く。

## 報告

人には、次のものを返す。

- 表と、前の月から大きく変わった所
- 星 2 以下のレビューから集めた不満
- カスタムプロダクトページを比べた結果

> [!WARNING]
> 売上のレポートの中身を読めるかは、確かめていない。

## 制約

API のキーの `.p8` のファイルは、リポジトリの外に置く。
