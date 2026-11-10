# claude-config の確かめ方

> [!NOTE]
> claude-config を変えた時に通すコマンドと、テストの置き方が分かる。
> 名前とスクリプトの書き方は [development.md](development.md) にある。

## 🚀 動かし方

claude-config を変えたら、`make verify` を通す。

| コマンド | 確かめること |
| --- | --- |
| `make verify` | `make audit` と `make test` を順に走らせる |
| `make audit` | config-audit.py で、文書と名前と置き場所と書き方の決まり |
| `make test` | `tests/` の種類のフォルダの全部で、フックとスクリプトの振る舞い |
| `make test-<対象>` | `tests/<種類>/<対象>.sh` の 1 本だけ |

> [!IMPORTANT]
> CI は、claude-config もアプリも置かない。PR は、手元の確認を通してから作る。

## 🧪 テスト

テストは、次の決まりで置く。

| 決まり | 中身 |
| --- | --- |
| 対象 | フックの `.py`、`scripts/` のファイル、`scripts/` を持つスキル |
| 置き場所と名前 | `tests/<種類>/<対象>.sh` に置く。名前は、対象の拡張子を除いた名前にする |
| 種類 | 対象の置き場所に合わせて、`hooks`・`scripts`・`skills` のどれかにする |
| 対応 | テストと対象が 1 対 1 でないと、config-audit が `NG` にする |
| 道具 | `rsync` と `jq` が要る |
| 上限 | 上限のあるものは、上限ちょうどが通るテストも置く |
| 一覧 | テストと共通の処理の一覧は、[tests/README.md](../../tests/README.md) にある。テストを足したら、その表に行を足す |
