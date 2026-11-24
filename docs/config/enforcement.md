# 設計の決まりの守り方

> [!NOTE]
> [code-design.md](../../dotclaude/rules/code-design.md) の決まりの 1 つ 1 つを、今は何で守っているかが分かる。
> 型で守れるようになった検査を消す時に、ここで確かめる。

## 📏 守り方の強さ

守り方は、強い順に次のように分ける。対応の表のセルは、いちばん強い守り方の名前で始める。

| 順 | 守り方 | 止まる時 | セルの書き方 |
| --- | --- | --- | --- |
| 1 | 型とモジュールの境界 | コンパイル | 型 |
| 2 | テストとスナップショット | アプリのテスト | テスト |
| 3 | 正規表現の検査 | `.swift` と `.kt` の Edit・Write の後と、アプリの `make verify` | 検査 |
| 4 | レビュー | PR を作る前の `reviewer` | レビューのみ |
| 5 | 決まりの文だけ | 止まらない | 文だけ |

検査の関数は、`lib/hooks/code_design_check/` にある。入口は `dotclaude/hooks/code-design-check.py` である。

`tests/hooks/code-design-check.sh` は、検査そのものを確かめる。アプリのコードは確かめない。

## 🗺️ 決まりと守り方

行は、code-design.md の節と表の順に並べる。数の上限・検査の範囲・基準線は、code-design.md の「守らせる仕組み」にある。

### 状態の持ち方

数を見る検査は、まとめ方の良し悪しまでは見ない。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 一緒に動く値 | 検査 `check_swift_state`。`@Observable` のクラスの `var` の数だけを見る | 検査 `check_kotlin_state`・`check_kotlin_parts`。`mutableStateOf` の `var` の数だけを見る |
| 両立しない状態 | 検査 `check_swift_state`。Bool の数だけを見る | 検査 `check_kotlin_parts`。まとまりのモデルの `State` の Boolean だけを見る |
| 表示中のもの | レビューのみ | レビューのみ |
| 段階のある処理 | レビューのみ | レビューのみ |
| 読み込んだ値 | レビューのみ | レビューのみ |
| 入力の下書き | レビューのみ | レビューのみ |
| 派生する値 | 検査 `check_swift_state`。`didSet` と `willSet` の数だけを見る | レビューのみ |
| 値を覚える | レビューのみ | レビューのみ |
| 今の時刻と今日 | 検査 `check_now`。引数とプロパティの既定値だけを見る | 検査 `check_now`。`Instant`・`LocalDate`・`LocalDateTime` の既定値だけを見る |
| 書き換える範囲 | レビューのみ。`private(set)` と書いた値は、コンパイルが守る | レビューのみ。`private set` と書いた値は、コンパイルが守る |

### モデルの形

右の列は、iOS のモデルを画面と別のモジュールに分けた後の守り方である。

| 決まり | Swift | Kotlin | 分けた後の Swift |
| --- | --- | --- | --- |
| まとまりだけを持つ | 検査 `check_swift_state`。直下の `var` だけを見て、余分な `let` は見ない | 検査 `check_kotlin_state`。直下の `mutableStateOf` だけを見る | 未確認 |
| まとまりの型と持つもの | レビューのみ | レビューのみ | 未確認 |
| `let`・`val` で持つ | レビューのみ。全部を `var` で書くと、検査はまとまりのモデルと見ない | レビューのみ。`var` で書くと、検査はまとまりのモデルと見ない | 未確認 |
| 連動する値 | 検査 `check_swift_state`。モデルと `State`・`Input` の `didSet` を 0 個にする | レビューのみ | 未確認 |
| 派生する値 | レビューのみ | レビューのみ | 未確認 |
| `Output` の中 | 検査 `check_swift_output` | 検査 `check_kotlin_parts`・`check_kotlin_output_extensions` | 未確認 |
| 入力の下書き | レビューのみ | レビューのみ | 未確認 |
| 今の時刻 | 検査 `check_swift_clock`。`dependencies.` を使うファイルだけを見る | 検査 `check_kotlin_clock`。`dependencies.` を使うファイルだけを見て、`LocalDate.now()` は見ない | 未確認 |
| View | 検査 `check_swift_access`。`.output.state` と `.output.input` だけを見て、転送のプロパティは見ない | 検査 `check_kotlin_access`。見る範囲は Swift と同じである | 未確認 |
| `input` に書く | 検査 `check_swift_input` | 検査 `check_kotlin_input`。代入だけを見て、`add` などの呼び出しは見ない | 型。`public internal(set)` にするので、画面から書くとコンパイルで止まる |
| 共通の型 | 許す決まりなので、守るものが無い | 許す決まりなので、守るものが無い | |
| 子のモデル | 検査 `check_swift_access`。`self` 以外の `.dependencies` の読み出しを見る | レビューのみ。`private` と書いた時は、コンパイルが守る | 型。`dependencies` が internal なので、画面から読むとコンパイルで止まる |
| 共通のプロトコル | レビューのみ | レビューのみ | 未確認 |
| `Output` と時刻 | レビューのみ。`dependencies.` の無いファイルの `Date()` は、検査が見ない | レビューのみ | 未確認 |
| 見せない持ち物 | レビューのみ | レビューのみ | 未確認 |

Kotlin の形の表は、次のように守る。

| まとまり | 守り方 |
| --- | --- |
| `state` | 検査 `check_kotlin_state`・`check_kotlin_parts`。直下の `mutableStateOf` と、`State` の中の数を見る |
| `input` | レビューのみ。`internal set` の有無は見ず、外からの代入を `check_kotlin_input` が見る |
| `output` | レビューのみ。`derivedStateOf` の置き場所は見ない |
| `dependencies` | レビューのみ。`private` の有無は見ない |

> [!WARNING]
> 次のことは、確かめていない。
>
> - 「未確認」の行が、モジュールを分けた後に型で止まるか。
> - Kotlin で型に移せる決まり。Android のモジュールは、まだ分けていない。
> - アプリのテストとスナップショットが守る決まり。

### 重複

同じ形の検査は、Swift と Kotlin を別々に比べる。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 書く前 | 文だけ。探したかどうかは、差分に出ない | 文だけ。探したかどうかは、差分に出ない |
| 2 つ目を書く | 検査 `Clones.check`。名前を伏せて、20 行以上の重なりだけを見る | 検査 `Clones.check`。見る範囲は Swift と同じである |
| 一覧を回す | レビューのみ | レビューのみ |
| 定型の並び | レビューのみ。20 行以上の写しは、`Clones.check` が当てる | レビューのみ。20 行以上の写しは、`Clones.check` が当てる |
| 括った後 | 検査 `check_parts`。共通の部品の一覧がある時だけ見る | レビューのみ |
| 別の OS へ写す | レビューのみ | レビューのみ |

### API の形

次の決まりは、Swift も Kotlin もレビューのみで守る。

- 引数
- 戻り値
- 対象が無い時
- エラーの型
- 型付きの値
- 2 つの場合
- 検証

### 置き場所

層の境目の Swift は、ひな形の `Package.swift` の依存の向きで確かめた。

| 決まり | Swift | Kotlin |
| --- | --- | --- |
| 計算 | レビューのみ | レビューのみ |
| 文字列の組み立て | レビューのみ | レビューのみ |
| 数値 | レビューのみ | レビューのみ |
| 層の境目 | 型。下のターゲットは上を import できず、文言を下の層に書くことだけはレビューで見る | 未確認 |
| ファイルの大きさ | 検査 `check_length`。テストのファイルも見る | 検査 `check_length`。テストのファイルも見る |
| ファイルと型 | 検査 `check_swift_name`・`check_swift_types` | 検査 `check_kotlin_types`。ファイルと同じ名前の型があるかは見ない |
