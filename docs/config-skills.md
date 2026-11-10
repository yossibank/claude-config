# スキル

> [!NOTE]
> どのスキルを、どの順に、誰が呼ぶかが分かる。
> フックやエージェントは [config-components.md](config-components.md) にある。

## 🗓️ 使う順

スキルは、Claude が要る時に自分で呼ぶ。人は `/<スキル>` で呼ぶ。名前の頭が分類を表し、分類は [接頭語の表](config-development.md#接頭語の表)にある。

アプリの企画から公開の後まで、次の順に使う。手入れのスキルは、どの段でも使う。

```mermaid
flowchart LR
    subgraph plan["企画と立ち上げ"]
        appPlan["app-plan"] --> appInit["app-init"]
    end
    subgraph build["作って出す（PR ごとに繰り返す）"]
        uiSnapshot["ui-snapshot"] -.->|見た目を確かめる| prCreate["pr-create"]
        uiRecord["ui-record"] -.->|動きを確かめる| prCreate
        codeDebug["code-debug"] -.->|不具合を直す| prCreate
        prCreate --> prFix["pr-fix"]
        prFix --> prPrune["pr-prune"]
    end
    subgraph store["App Store"]
        storeRelease["store-release"] --> storeReport["store-report"]
        storeReport -->|低い評価| storeReply["store-reply"]
    end
    subgraph care["手入れ（いつでも）"]
        ctxReport["ctx-report"]
        configLearn["config-learn"]
        configReview["config-review"]
        docsPolish["docs-polish"]
    end
    appInit --> prCreate
    prPrune --> storeRelease
    storeReport -->|数字と不満を次の企画へ| appPlan
```

## 🧰 一覧

呼ぶ人は、絵文字で分ける。🙋 は人が頼んだ時だけ、🤝 は人と Claude、🧠 は Claude だけが呼ぶ。

> [!IMPORTANT]
> pr-create・store-release・store-reply は外に出す操作を含む。人が言葉で頼んだ時だけ呼び、外に出す前に承認を得る。

### 企画と立ち上げ

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [app-plan](../skills/app-plan/SKILL.md) | 🤝 人と Claude | 競合のレビューの不満を集め、overview と roadmap の下書きを作る |
| [app-init](../skills/app-init/SKILL.md) | 🤝 人と Claude | ひな形から、ビルドとテストが通るアプリのリポジトリを作る |

### 作って出す

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [ui-snapshot](../skills/ui-snapshot/SKILL.md) | 🧠 Claude だけ | SwiftUI の画面をテストとして描き、場合ごとの PNG にする |
| [ui-record](../skills/ui-record/SKILL.md) | 🧠 Claude だけ | シミュレーターを録画し、確かめたい場面のコマを並べる |
| [code-debug](../skills/code-debug/SKILL.md) | 🤝 人と Claude | 再現・3 つの仮説・検証で原因を確かめ、承認された直し方と再現テストを入れる |
| [pr-create](../skills/pr-create/SKILL.md) | 🙋 人が頼んだ時だけ | 差分の大きさに合わせた確認とレビューを通して PR を作る |
| [pr-fix](../skills/pr-fix/SKILL.md) | 🤝 人と Claude | 落ちた CI と未解決の指摘を直し、push し直す |
| [pr-prune](../skills/pr-prune/SKILL.md) | 🤝 人と Claude | マージされた PR の反映と片付け。main に反映し、ワークツリーとブランチを消す |

### App Store

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [store-release](../skills/store-release/SKILL.md) | 🙋 人が頼んだ時だけ | 申告・掲載情報・スクリーンショットを確かめ、アーカイブを送る。カスタムプロダクトページを作る |
| [store-report](../skills/store-report/SKILL.md) | 🤝 人と Claude | 全アプリの月ごとのダウンロード・収益・評価を表にする |
| [store-reply](../skills/store-reply/SKILL.md) | 🙋 人が頼んだ時だけ | 返信していない低い評価のレビューに返信案を書き、承認された案を送る |

### 手入れ

| スキル | 呼ぶ人 | すること |
| --- | --- | --- |
| [ctx-report](../skills/ctx-report/SKILL.md) | 🤝 人と Claude | 月ごとに、トークンを多く使った作業を表にする |
| [config-learn](../skills/config-learn/SKILL.md) | 🤝 人と Claude | 繰り返した手直しとフックの回数から、決まりの改定案を出す |
| [config-review](../skills/config-review/SKILL.md) | 🤝 人と Claude | claude-config を観点ごとに調べ、台帳に無い改善だけを出す |
| [docs-polish](../skills/docs-polish/SKILL.md) | 🤝 人と Claude | 文字だけが続く節を見つけ、表・図・絵文字で見やすくする案を見本付きで出す |
