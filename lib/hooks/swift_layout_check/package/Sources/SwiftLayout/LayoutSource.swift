import Foundation
import SwiftParser
import SwiftSyntax

struct LayoutSource {
    let stem: String
    let text: String
    let tree: SourceFileSyntax
    let converter: SourceLocationConverter

    init(
        path: String,
        text: String
    ) {
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let tree = Parser.parse(source: text)

        self.stem = name
        self.text = text
        self.tree = tree
        self.converter = SourceLocationConverter(fileName: path, tree: tree)
    }

    init?(path: String) {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        self.init(path: path, text: text)
    }
}

extension LayoutSource {
    var subject: String {
        stem.split(separator: "+").first.map(String.init) ?? stem
    }

    func line(of node: some SyntaxProtocol) -> Int {
        node.startLocation(converter: converter).line
    }

    func endLine(of node: some SyntaxProtocol) -> Int {
        node.endLocation(converter: converter).line
    }

    func lineCount(of node: some SyntaxProtocol) -> Int {
        endLine(of: node) - line(of: node) + 1
    }

    func isMultiline(_ node: some SyntaxProtocol) -> Bool {
        lineCount(of: node) > 1
    }

    func hasBlankLine(before node: some SyntaxProtocol) -> Bool {
        node.leadingTrivia.contains { piece in
            if case let .newlines(count) = piece {
                return count > 1
            }

            return false
        }
    }

    func finding(
        at node: some SyntaxProtocol,
        _ message: String,
        blank: Bool? = nil
    ) -> LayoutFinding {
        let edit = blank.flatMap { blankEdit(before: node, inserts: $0) }
        return LayoutFinding(line: line(of: node), message: message, edit: edit)
    }

    func blankEdit(
        before node: some SyntaxProtocol,
        inserts: Bool
    ) -> LayoutEdit? {
        let trivia = node.leadingTrivia.description
        let start = node.position.utf8Offset

        guard trivia.allSatisfy(\.isWhitespace) else {
            return nil
        }

        if inserts {
            return LayoutEdit(start: start, end: start, text: "\n")
        }

        let indent = trivia.split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
        let end = node.positionAfterSkippingLeadingTrivia.utf8Offset

        return LayoutEdit(start: start, end: end, text: "\n" + indent)
    }

    func slice(
        from start: AbsolutePosition,
        to end: AbsolutePosition
    ) -> String {
        let bytes = Array(text.utf8)[start.utf8Offset..<end.utf8Offset]
        return String(decoding: bytes, as: UTF8.self)
    }
}
