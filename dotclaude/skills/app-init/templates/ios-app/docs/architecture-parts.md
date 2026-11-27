# 共通の部品の一覧

> [!NOTE]
> 複数の画面で使う仕組みの名前、使いどころ、置き場所が分かる。
> 共通の形は、claude-config の `docs/app/ios-screens.md` にある。

## 🪝 土台

画面とモデルをつなぐ型と関数である。新しい画面は、claude-config の `code-screen` のスキルで、この名前のまま足せる。

| 仕組み | 使いどころ | 置き場所 |
| --- | --- | --- |
| `ScreenParts` | DB・時計・待ちを包んで、画面からモデルへ渡す。中の DB は `FeatureModels` だけが読む | `FeatureModels/Shared/Model/` |
| `ScreenClock` | モデルの時計。テストでは `fixed` で止める | `FeatureModels/Shared/Model/` |
| `ScreenPerforming` | 画面がモデルの async の関数を呼ぶ口。`perform` が `Task` を始め、画面は `Task` を書かない | `FeatureModels/Shared/Model/` |
| `ScreenOutcome` | 保存できた・消した、の結果を 1 つ持つ。モデルの `state` に置く | `FeatureModels/Shared/Model/` |
| `onOutcome` | 画面が `ScreenOutcome` の変化を受ける modifier | `Features/Shared/Model/` |
| `ScreenEditable` | 画面が書いてよい値の型の印。`state` の `fields` と `presented` の型に付ける | `FeatureModels/Shared/Model/` |
| `Shown` | 表示中のシート・確認・メニューを、`presented` に名前付きで並べる。確認には `prompt[.delete]` で `Binding` を渡す | `FeatureModels/Shared/Model/` |
| `ModelTask` | 保存などの実行中の印。`state.task` に置き、二度押しは呼ぶ側が `isRunning` で止める | `FeatureModels/Shared/Model/` |
| `ScreenWait` | 知らせを消すまでの待ち。`ScreenParts` が持ち、テストでは差し替える | `FeatureModels/Shared/Model/` |
| `ErrorNotice` | 時間で消えるエラーの知らせ。`state.notices.error` に置く | `FeatureModels/Shared/Model/` |
| `Loadable` | 読み込み中・読めた・失敗を 1 つの値で持ち、値と読んだ印を組にしない | `FeatureModels/Shared/Model/` |

## 🪜 入れ物の作り方

`ScreenParts` は、次の関数で作る。画面と入口は、DB のモジュールを import しない。

| 仕組み | 使いどころ | 置き場所 |
| --- | --- | --- |
| `ScreenParts.appGroup(clock:)` | App Group の DB を開いて作る。`RootView` が `AppModel` に渡す | `FeatureModels/Shared/Model/` |
| `ScreenParts.preview()` | メモリの DB で作る。`#Preview` で使う | `FeatureModels/Shared/Model/` |
