---
name: store-report
description: 公開している全アプリの、月ごとのダウンロード・収益・評価・レビューを 1 枚の表にする。月の初めに前の月の数字を見る時や、人がアプリの数字を聞いた時に使う。
argument-hint: "<YYYY-MM>"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/*)
---

# アプリの数字をまとめる

公開している全アプリの数字を、月ごとの表にまとめる手順。月の初めに、前の月の分を作る。

## 使い方

表は、次のコマンドで作る。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/monthly.py <YYYY-MM>
```

`monthly.py` は、`~/Applications/AppStore/*/store/app-id.txt` を持つアプリを集め、表を `~/Applications/AppStore/reports/<YYYY-MM>.md` に書く。置き場所は `APPS_DIR` で変えられる。`app-id.txt` には、App Store の ID（数字）だけを書く。

## 表の中身

表の列は、次のとおりである。

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

## 読み方

人には、表と、前の月から大きく変わった所だけを返す。星 2 以下のレビューが増えたアプリは、`reviews.py`（`app-plan` のスキル）で中身を読み、不満を 3 つまでにまとめる。

> [!WARNING]
> 売上のレポートの取得は、キーが無いので確かめていない。署名は、テスト用の鍵で `openssl` の検証に通ることだけを確かめた。
