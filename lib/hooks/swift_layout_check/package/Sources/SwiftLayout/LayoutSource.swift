import Foundation
import SwiftParser
import SwiftSyntax

struct LayoutSource {
    let stem: String
    let tree: SourceFileSyntax
    let converter: SourceLocationConverter

    init?(path: String) {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let tree = Parser.parse(source: text)

        self.stem = name
        self.tree = tree
        self.converter = SourceLocationConverter(fileName: path, tree: tree)
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
        _ message: String
    ) -> LayoutFinding {
        LayoutFinding(line: line(of: node), message: message)
    }
}
