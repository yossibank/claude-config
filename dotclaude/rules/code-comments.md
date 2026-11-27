---
paths:
  - "**/*.swift"
  - "**/*.{kt,kts}"
  - "**/Makefile"
  - "**/*.{yml,yaml,toml}"
  - "**/*.sh"
---

# コメント

Swift・Kotlin のコードと、設定・シェルスクリプト・CI を読み書きする時に読み込まれる決まり。

> [!IMPORTANT]
> **コメントを書かない。** 要ると判断したら、書かずに提案する。

道具が読む指定だけは、コメントの形でも残す。ほかのコメントは、`code-check-comments` のフックが止める。

| 残すもの | 例 |
| --- | --- |
| 1 行目のシェバン | `#!/bin/bash` |
| `Package.swift` の 1 行目 | `// swift-tools-version: 6.0` |
| 整形と検査の道具への指定 | `// swiftlint:`、`// swiftformat:`、`# shellcheck`、`// ktlint-` |
