---
name: store-release
description: App Store に出す前の申告・掲載情報・スクリーンショット・版を確かめ、アーカイブを TestFlight に送る。人がストアへの公開や配布を頼んだ時に使う。
argument-hint: "[<アプリのリポジトリ>]"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/*), Bash(${CLAUDE_SKILL_DIR}/scripts/screenshot.sh *)
---

# ストアに出す

App Store に出す前に要るものをそろえて確かめ、アーカイブを App Store Connect に送る手順。審査への提出は、人が App Store Connect で行う。

## 入力

公開に使うファイルは、アプリのリポジトリの次の場所に置く。無ければ、表のひな形から写して作る。

| ファイル | ひな形 | 中身 |
| --- | --- | --- |
| `ios/<App>/PrivacyInfo.xcprivacy` | claude-config の `templates/ios-app/` にある同じ名前のファイル | 理由の申告が要る API と、集めるデータ |
| `store/ja/*.txt` | `templates/ja/` | 名前、サブタイトル、キーワード、説明、宣伝文、更新の説明、サポートとプライバシーポリシーの URL |
| `store/screenshots/` | | 6.9 インチの PNG |

## 手順

公開の準備は、次の順に進める。1 つでも `NG` が出たら、直してから次へ進む。

1. プライバシーの申告を確かめる。
2. 掲載情報を書いて確かめる。
3. スクリーンショットを撮る。
4. 版の番号を決める。
5. アーカイブを作って送る。
6. 人に、App Store Connect でする作業を渡す。

### 1. プライバシーの申告

`privacy-check.py` は、Swift のコードから理由の申告が要る API を探し、申告と突き合わせる。

- 突き合わせる先は、そのファイルに一番近い上の階層の `PrivacyInfo.xcprivacy` である
- 近くに無ければ、アプリの申告と突き合わせる
- テストのコードは見ない

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/privacy-check.py <アプリのリポジトリ>
```

`NG` の API は、理由のコードを選んで申告する。コードは、Apple の「Describing use of required reason API」にある。

理由が選べない時は、人に聞く。ライブラリは、それぞれが持つ申告を使う。

### 2. 掲載情報

`store/ja/` の文を書き、`listing-check.py` で字数と抜けを確かめる。上限は、名前とサブタイトルが 30 字、キーワードが 100 字、宣伝文が 170 字、説明が 4000 字である。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/listing-check.py <アプリのリポジトリ>/store/ja
```

説明の文は、overview の「解決したい不満」と「最初のリリースの機能」から書く。キーワードはカンマで区切り、名前とサブタイトルにある語は入れない。

### 3. スクリーンショット

6.9 インチのシミュレーター（iPhone 18 Pro Max など）でアプリを開き、見せたい画面ごとに撮る。`screenshot.sh` は、状態バーを 9:41・電池 100% に固定して撮り、大きさを確かめる。

```sh
${CLAUDE_SKILL_DIR}/scripts/screenshot.sh <UDID> <アプリのリポジトリ>/store/screenshots/<番号>-<画面>.png
```

撮る画面は 3〜5 枚にし、overview の「解決したい不満」の上位に応える画面から並べる。見せたい状態のデータは、テストデータを入れて作る。

### 4. 版の番号

`MARKETING_VERSION` を人に確かめる。ビルドの番号は、送る時に Xcode が上げる。

### 5. アーカイブと送信

`archive.sh` は、Release でアーカイブを作り、App Store Connect に送る。外に出す操作なので、走らせる前に人の承認を得る。

```sh
${CLAUDE_SKILL_DIR}/scripts/archive.sh <ワークスペース> <スキーム> <出力先のフォルダ>
```

| 変数 | すること |
| --- | --- |
| `ARCHIVE_ONLY=1` | アーカイブだけを作り、送らない |
| `EXPORT_DESTINATION=export` | 送らずに、出力先に IPA を書き出す |

全ログは、出力先の `archive.log` にある。失敗した時は、`error:` の行だけを出す。

## 報告

人には、通した確認の結果と、App Store Connect で人がすることを返す。終えたら、人に結果を聞く。

- App のプライバシー（集めるデータの申告）に答える
- 年齢の区分、価格、配信する国を決める
- 掲載情報とスクリーンショットを入れる
- TestFlight で、送ったビルドを実機で確かめる
- 審査に出す

> [!WARNING]
> 書き出しと送信には、配布用の署名と App Store Connect のアカウントが要る。手元では確かめていない。
