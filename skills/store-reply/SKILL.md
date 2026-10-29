---
name: store-reply
description: 全アプリの、まだ返信していない星 2 以下のレビューに返信案を書き、人が承認した案だけを App Store に送る。人がレビューへの返信を頼んだ時だけ使う。
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/collect-reviews.py*)
---

# レビューに返信する

App Store の低い評価のレビューに、返信案を書いて送る手順。送るのは、人が承認した案だけである。

## 起動条件

人が、レビューへの返信を言葉で頼んだ時だけ使う。store-report で星 2 以下が増えた時は、使うかを人に聞く。

## 入力

集めるアプリと返信案の置き場所は、次のとおりである。置き場所は `CC_APPS_DIR` で変えられる。

| 読むもの・書くもの | 場所 |
| --- | --- |
| 集めるアプリ | `~/Applications/AppStore/*/store/app-id.txt` を持つもの |
| 返信案 | `~/Applications/AppStore/replies/<YYYY-MM-DD>.json` |

キーの環境変数と役割は、[store-report](../store-report/SKILL.md) の「API のキー」にある。`ASC_VENDOR_NUMBER` は要らない。

## 手順

返信は、次の順に進める。

1. 返信していないレビューを、下のコマンドで返信案のファイルに集める。
2. ファイルの各レビューの `reply` に、「返信の決まり」に従って返信案を書く。
3. 人に、レビューの本文と返信案を並べて見せ、送ってよい案を聞く。
4. 承認された案だけ、`approved` を `true` にする。直すよう言われた案は、直してもう一度見せる。
5. `--dry-run` を付けて、送る中身を出して確かめる。
6. 人に送ってよいかを確かめてから、`--dry-run` を外して送る。

レビューは、次のコマンドで集める。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/collect-reviews.py
```

送る中身は、次のコマンドで出す。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/send-replies.py <返信案の JSON> --dry-run
```

承認を得たら、次のコマンドで送る。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/send-replies.py <返信案の JSON>
```

## collect-reviews.py がすること

`collect-reviews.py` は、アプリごとに星 2 以下のレビューを新しい順にすべて読む。返信のあるレビューを除き、返信案のファイルに書く。

- 同じ日のファイルがあれば、書きかけの案と承認を残す。壊れていれば、集める前に `NG` で止まる。
- 読めなかったアプリは stderr に知らせ、ほかのアプリを続ける。
- どのアプリも読めなかった時は、`NG` で止まる。

返信案のファイルは、レビューの配列である。1 件の項目は、次のとおりである。

| 項目 | 中身 | 書く人 |
| --- | --- | --- |
| `app` | アプリのリポジトリの名前 | collect-reviews.py |
| `id` | レビューの ID | collect-reviews.py |
| `rating`・`date`・`territory` | 星、書かれた日（日本時間）、国（`JPN` など） | collect-reviews.py |
| `title`・`body` | レビューの題と本文 | collect-reviews.py |
| `reply` | 返信案 | Claude |
| `approved` | 人が承認したら `true` | Claude |
| `sent` | 送った返信の ID | send-replies.py |

## 返信の決まり

返信は公開され、誰でも読める。次の決まりで書く。

| 決まり | 中身 |
| --- | --- |
| 言語 | レビューの本文と同じ言語で書く |
| 謝る | 初めの 1 文で、不便をかけたことを謝る |
| 次の一手 | 回避の手順・直す予定・問い合わせ先のどれかを、具体的に書く |
| 約束しない | roadmap に無い機能と、直す日付を書かない。要望は「検討する」に留める |
| 個人情報 | メールアドレス・電話番号・アカウントを尋ねない。問い合わせは、サポートの URL へ案内する |
| URL | アプリの `store/ja/support_url.txt` の URL だけを書く |
| 書かないこと | 評価を変えてほしいという頼み。レビューを書いた人を責める言葉 |
| 長さ | 5970 字まで。ふつうは 3〜5 文にする |

## send-replies.py がすること

`send-replies.py` は、`approved` が `true` で、`sent` の無い案だけを送る。

- 送る前に全部の案を確かめ、空か 5970 字を超える案が 1 つでもあれば、何も送らずに `NG` を出す。
- 送る前に、そのレビューに返信が既にあるかを確かめる。あれば送らずに、その返信の ID を `sent` に書く。
- 1 件送るごとに `sent` をファイルに書く。失敗したら、そこで止まる。
- 止まった後に走らせ直すと、残りの案だけを送る。
- `--dry-run` を付けると、返信の確認もせず、キーも通信も使わずに送る JSON を 1 件 1 行で出す。

## 報告

人には、集めた件数、送った件数、送れなかった案と理由を返す。

> [!WARNING]
> 実際の App Store Connect API では試していない。偽の応答で、集め方と送る中身の形だけを確かめた。

## 制約

- 人が頼んだ時だけ使う。
- `send-replies.py` は外に出す操作なので、`--dry-run` を付けない時は、走らせる前に人の承認を得る。
- 人が承認していない案の `approved` を `true` にしない。
