import Foundation

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
        let descriptor = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)

        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

        try handle.write(contentsOf: line + Data("\n".utf8))
    }
}
