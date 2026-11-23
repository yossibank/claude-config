import Foundation

/// 描いた PNG ごとに、人が読む画面の名前と描き方を、出力先の `index.jsonl` に 1 行ずつ足す。
enum SnapshotIndex {
    static func record(
        directory: String,
        file: String,
        title: String,
        variant: String
    ) throws {
        let entry = ["file": file, "title": title, "variant": variant]
        let line = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
        let path = URL(fileURLWithPath: directory).appending(path: "index.jsonl").path
        // 並列のテストが同時に書いても行が混ざらないように、追記で開いて 1 回で書く
        let descriptor = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)

        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

        try handle.write(contentsOf: line + Data("\n".utf8))
    }
}
