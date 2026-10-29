---
name: store-report
description: 公開している全アプリの、月ごとのダウンロード・収益・評価・レビューを 1 枚の表にする。月の初めに前の月の数字を見る時や、人がアプリの数字を聞いた時に使う。
argument-hint: "<YYYY-MM>"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/*)
---

# アプリの数字をまとめる

公開している全アプリの数字を、月ごとの表にまとめる手順。月の初めに、前の月の分を作る。

## 手順

表は、次のコマンドで作る。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/write-report.py <YYYY-MM>
```

`write-report.py` は、アプリを集めて表を書く。置き場所は `CC_APPS_DIR` で変えられる。

| 読むもの・書くもの | 場所 |
| --- | --- |
| 集めるアプリ | `~/Applications/AppStore/*/store/app-id.txt` を持つもの。中身は App Store の ID（数字）だけ |
| 表 | `~/Applications/AppStore/reports/<YYYY-MM>.md` |

## write-report.py の出力

`write-report.py` が書く表の列は、次のとおりである。

| 列 | 出どころ | 要るもの |
| --- | --- | --- |
| ダウンロード | 売上のレポート。新規のダウンロードだけを数え、更新は数えない | API のキー |
| 収益 | 売上のレポートの手取り。通貨ごとに足す | API のキー |
| 評価、評価の数 | 日本の App Store の公開の情報 | なし |
| 今月のレビュー、星 2 以下 | 日本の App Store の公開のレビュー。新しい順に 500 件まで | なし |

取れなかった列は `—` にし、理由を表の下の WARNING に書く。

## API のキー

売上のレポートは、App Store Connect API から取る。次の環境変数を、`~/.zshenv` などで渡す。キーのファイルは、リポジトリの外に置く。

| 環境変数 | 中身 |
| --- | --- |
| `ASC_ISSUER_ID` | キーの Issuer ID |
| `ASC_KEY_ID` | キーの ID |
| `ASC_KEY_PATH` | `.p8` のファイルのパス |
| `ASC_VENDOR_NUMBER` | 「支払いと財務レポート」にあるベンダー番号 |

キーは、App Store Connect の「ユーザとアクセス」で、「財務」以上の役割で作る。

## 報告

人には、表と、前の月から大きく変わった所だけを返す。

星 2 以下のレビューが増えたアプリは、中身を読んで不満を 3 つまでにまとめる。読むには、`app-plan` のスキルの `fetch-reviews.py` を使う。

> [!WARNING]
> 売上のレポートの取得は、キーが無いので確かめていない。署名は、テスト用の鍵で `openssl` の検証に通ることだけを確かめた。
