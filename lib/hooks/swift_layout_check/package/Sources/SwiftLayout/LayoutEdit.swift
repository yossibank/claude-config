struct LayoutEdit {
    let start: Int
    let end: Int
    let text: String
}

extension LayoutEdit {
    static func apply(
        _ edits: [LayoutEdit],
        to text: String
    ) -> String {
        var bytes = Array(text.utf8)
        var limit = bytes.count

        for edit in edits.sorted(by: { $0.start > $1.start }) where edit.end <= limit {
            bytes.replaceSubrange(edit.start..<edit.end, with: Array(edit.text.utf8))
            limit = edit.start
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}
