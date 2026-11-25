---
name: code-screen
description: Swift と Kotlin の新しい画面を、モデル・画面・テストのひな形から、設計の検査を通る形で足す。アプリに画面を足す時や、人が新しい画面を頼んだ時に使う。
argument-hint: "<画面の名前> <扱う型の名前> [list|edit] [sync]"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/create-screen.py *)
---

# 画面を足す

新しい画面を、ひな形から始めて `rules/code-design.md` の形で足す手順。ひな形は `${CLAUDE_SKILL_DIR}/templates/` にあり、言語と形で分かれる。

## 起動条件

画面の形で、使うひな形を決める。

| 場面 | すること |
| --- | --- |
| DB の一覧を見張って出す画面 | 形 `list` を使う |
| 入力して保存し、結果で閉じる画面 | 形 `edit` を使う |
| アプリが DB を同期で呼ぶ | 同じ形に `Database=sync` を足す。下の「同期の版」に従う |
| 同じ形の画面が、アプリに既にある | 先に、その画面の共通の部品を探して載せる。無ければ、2 つを括ってから足す |
| 表示だけで、処理の無い画面 | 使わない。モデルを置かずに書く |
| DesignSystem の部品 | 使わない。モデルを持てない |

## 入力

`create-screen.py` には、名前を `<名前>=<値>` で渡す。

| 名前 | 中身 | 例 |
| --- | --- | --- |
| `Screen` | 画面の名前。モデルは `<Screen>Model` になる | `StampList` |
| `Item` | 画面が扱う Core の型 | `Stamp` |
| `View` | 画面の型の名前。省くと `<Screen>View` になる | `StampEditSheet` |
| `Database` | DB の呼び方。`async` か `sync` で、省くと `async` になる | `sync` |
| 土台の名前 | アプリで名前が違う時だけ、`<既定の名前>=<アプリの名前>` で渡す | `ScreenParts=AppParts` |

## 手順

画面は、次の順に足す。段ごとに決めることは、下の「段ごとに決めること」にある。

1. アプリの `docs/` の構成の文書で、置き場所と名前を決める。
2. 土台の型があるかを、アプリの `docs/architecture-parts.md` で確かめる。
3. 扱う型と下書きの型が Core に、読み書きの関数が Store にあるかを確かめる。無ければ、先に足す。
4. `create-screen.py` を走らせ、モデル・画面・テストを置く。
5. モデルを書く。ひな形の `name` と DB の関数を、アプリの物に替える。
6. テストを書く。モデルの関数ごとに、できた時とできない時を確かめる。
7. 画面を書く。行と入力欄の中身を、アプリの DesignSystem の部品に替える。
8. 親の画面からつなぐ。
9. アプリの一覧と文書を直す。
10. アプリの `make verify` を通す。

```sh
python3 -I ${CLAUDE_SKILL_DIR}/scripts/create-screen.py <swift|kotlin> <list|edit|base> <モデルのフォルダ> <画面のフォルダ> <テストのフォルダ> [<名前>=<値>...]
```

## 段ごとに決めること

段の番号は、手順の番号である。

| 段 | 決めること | 落とし穴 |
| --- | --- | --- |
| 1 | モデル・画面・テストのフォルダと、画面の名前 | モデルのモジュールが別にあるアプリは、モデルをそこに置く。画面のモジュールに置くと、型が守らない |
| 2 | 口・結果・入れ物・時計の、アプリでの名前 | 一覧に行が無い時は、下の「土台」に従う。推測で名前を当てない |
| 3 | 画面が読む値と、書く操作 | 計算は Core に、読み書きは Store に置く。モデルに SQL や集計を書かない |
| 4 | 形と、渡す名前 | 同じ形の 2 つ目を中身を書かずに置くと、同じ形の検査が止める |
| 5 | `state`・`input`・`output` に置く値 | 人が変える値は `state`、DB から来る値は `input`、計算は `output` に置く。使わないまとまりは消す |
| 5 | 結果の型 | 結果は、できた時だけ `state` の `outcome` に 1 回置く。何種類もある時は、1 つの `enum` にする |
| 6 | 確かめる筋書き | DB はメモリに開き、時計は固定する。Kotlin の `perform` は Main が要るので、テストはモデルの関数を直接呼ぶ |
| 7 | `Layout` に置く見た目の値 | 意味のある状態を、画面の `@State` や `remember` に置かない。使わない `Layout` は消す |
| 7 | 入口と出口 | ボタンからは `perform` で呼ぶ。結果は、`onOutcome`（Kotlin は `OnOutcome`）の 1 か所で受ける |
| 8 | 親が開く時に持つ値 | 開いている画面は、親のモデルの `state` の 1 つの値で持つ。子のモデルは、親のモデルの関数が作る |
| 9 | 直す一覧と文書 | 画面のフォルダの表・共通の部品の一覧を直す。筋書きの一覧があれば、テストの行を足して別の OS の扱いを決める |
| 10 | 残った外れの直し方 | 基準線に足して通さない。ひな形の形に戻して直す |

## 同期の版

同期の版は、DB を `try` だけで呼ぶアプリのための版である。Swift の `list` と `edit` にだけある。

| 場面 | すること |
| --- | --- |
| アプリの `docs/architecture.md` に、DB を同期で呼ぶとある | `Database=sync` を渡す |
| 文書に書いていない | Store の関数に `async` が付くかを見る。付かなければ、`Database=sync` を渡す |
| Kotlin の画面 | 同期の版は無い。要るアプリが出た時に足す |

非同期の版との違いは、次のとおりである。

| 対象 | 非同期の版 | 同期の版 |
| --- | --- | --- |
| 最初の読み込み | 画面の `.task` が `run()` を呼ぶ | モデルの `init` が `refresh()` を呼ぶ |
| DB の変化 | 見張り（`AsyncSequence`）で受ける | 画面が `refresh()` を呼び直す |
| 一覧の値 | 読むまで `nil` で、`output` が空の配列にする | 最初から配列で、画面は `input` を読む |
| 保存と削除 | async の関数を `perform` で呼ぶ | 同期の関数を、ボタンから直接呼ぶ |
| 二重の保存 | `state` の `isSaving` で止める | 保存した下書きを `input` に置き、変更が無ければ止める |
| 口 | モデルは `ScreenPerforming` である | 口を持たない。土台に `ScreenPerforming` が無くても置ける |

結果は、どちらの版も `state` の `outcome` に置き、画面が `onOutcome` で受ける。

同期の版の落とし穴は、次のとおりである。

| 落とし穴 | すること |
| --- | --- |
| モデルが `init` で読む | テストとスナップショットは、最初から中身入りになる。DB の中身を、モデルを作る前に入れる |
| ほかの画面の書き込みが出ない | 画面が出た時と前面に戻った時に、`refresh()` を呼ぶ。子の画面の結果を受けた時も呼ぶ |
| `Output` に DB を読ませたくなる | 読むのは `refresh()` だけにする。`Output` は `input` と `state` から計算する |
| `refresh()` に書き込みを足したくなる | 読み直すだけにする。書き込みは、別の関数にして `refresh()` の前に呼ぶ |
| 本当に非同期の処理が要る | OS の許可の依頼などだけ、モデルを `ScreenPerforming` にして `perform` で呼ぶ |

## create-screen.py がすること

`create-screen.py` は、ひな形の印を置き換えて、3 つのフォルダに置く。

- 形が `list` と `edit` の時は、土台の型と関数の宣言をリポジトリから探す。無ければ、`NG` を出して止まる。
- 形が `base` の時は、土台を置く。土台の宣言が既にあれば、`NG` を出して止まる。
- 置く先に同じ名前のファイルがあれば、`NG` を出して止まる。`NG` の時は、ファイルを 1 つも置かない。
- Swift は、モデルのフォルダの `Sources/<ターゲット>` を画面とテストの import にする。同じターゲットなら import を書かない。
- Kotlin は、フォルダの場所から package を決める。土台・DB・扱う型の import は、宣言のあるファイルの package から決める。
- `Database=sync` の時は、`templates/swift/<形>-sync/` のひな形を置く。土台の `ScreenPerforming` は探さない。
- `Database=sync` を Kotlin か形 `base` に渡すと、`NG` を出して止まる。
- 置いたファイルを、`OK` の行で出す。

## ひな形

ひな形は、kakeibot の実物からアプリだけの中身を抜いた物である。同期の版は、unscroll のモデルの読み方に合わせている。

| 形 | 土台にした実物 | 置くファイル |
| --- | --- | --- |
| `list` | テンプレートの一覧のモデル（`TemplateListModel`）と、記録のタブの結果の受け方 | `<Screen>Model`・`<View>`・`<Screen>ModelTests` |
| `edit` | 残高を合わせるシート（`AssetsAdjustmentModel`）と、テンプレートの編集のモデル | `<Screen>Model`・`<View>`・`<Screen>ModelTests` |
| `base` | `FeatureModels/Shared/Model/` の土台の型 | 下の「土台」の表の型 |
| 同期の `list` | unscroll の絵はがきの一覧（`PostcardAlbumModel`）の `init` と `refresh()` | `list` と同じ |
| 同期の `edit` | unscroll の相棒を選ぶ画面（`CompanionPickerModel`）の保存 | `edit` と同じ |

ひな形は、次の名前を決めてかかる。アプリの物と違う所は、置いた後に替える。

| 決めてかかる物 | ひな形の書き方 |
| --- | --- |
| 扱う型 | `id` と `name` を持つ。Swift は `Identifiable` である |
| 下書きの型 | `<Item>Draft(name:)` で作り、比べられる。`problems` が問題の一覧を返す |
| DB の関数 | `<item>List`・`<item>ListUpdates`・`save<Item>`・`delete<Item>` |
| 同期の版の DB の関数 | 同じ名前で、`async` が付かない。`<item>ListUpdates` は使わない |
| メモリの DB | `AppDatabase.inMemory()` |
| 失敗の知らせ | `state` の `failureMessage` の文字。アプリに知らせの型があれば、それに替える |
| Kotlin の DB の関数 | クラスの関数として呼ぶ。拡張の関数なら、import を足す |

## 土台

土台は、画面とモデルをつなぐ型と関数である。名前は kakeibot の物を既定にしている。

| 役割 | 既定の名前 | 言語 |
| --- | --- | --- |
| 画面がモデルの処理を始める口 | `ScreenPerforming` の `perform` | Swift・Kotlin |
| モデルが画面へ返す結果 | `ScreenOutcome` | Swift・Kotlin |
| 画面が結果を受ける所 | `onOutcome`（Kotlin は `OnOutcome`） | Swift・Kotlin |
| モデルの時計 | `ScreenClock` | Swift・Kotlin |
| 画面が中を開けずに渡す、DB の入れ物 | `ScreenParts` | Swift |

土台の有無と名前は、次のように扱う。

| 場面 | すること |
| --- | --- |
| 一覧に、同じ役割の型が別の名前である | `<既定の名前>=<アプリの名前>` で渡す |
| 一覧にも、コードにも無い | 人に確かめてから、形 `base` で土台だけを足す。土台は、画面と別の commit にする |
| 土台を足した | 共通の部品の一覧に行を足す。口と結果の決まりを、画面の組み立ての文書に書く |
| 役割の一部だけがある | 止めて、人に聞く。足りない型を、推測で作らない |

モジュールの名前の `Core`・`Store` と、DB の型の `AppDatabase` も、同じ書き方で替えられる。

## 報告

人には、次のものを返す。

- 置いたファイルと、使った形
- 土台を足したか、名前を置き換えたか
- ひな形から替えた所（扱う型の項目、DB の関数、知らせ）
- アプリの `make verify` の結果
- 直した一覧と文書

## 制約

| 制約 | 中身 |
| --- | --- |
| 土台 | 人に確かめずに足さない。足す時は、画面より先に、土台だけで検査を通す |
| 基準線 | ひな形から足した画面の外れを、基準線に書かない |
| 画面の非同期 | 画面に `Task` と `rememberCoroutineScope` を足さない。モデルの関数にして、`perform` で呼ぶ |
| DB | Swift の画面は、DB のモジュールを import しない。入れ物をそのまま、モデルの init へ渡す |
| コンパイル | ひな形は、仮の型でビルドとテストを通してある。アプリの型に替えた後に、もう一度通す |
