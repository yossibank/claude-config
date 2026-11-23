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
        let url = URL(fileURLWithPath: directory).appending(path: "index.jsonl")
        let manager = FileManager.default

        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)

        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        try handle.write(contentsOf: line + Data("\n".utf8))
    }
}
