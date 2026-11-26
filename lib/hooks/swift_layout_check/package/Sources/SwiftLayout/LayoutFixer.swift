import Foundation
import SwiftSyntax

enum LayoutFixer {
    static let maxPasses = 400
    static let indent = "    "

    static func fix(
        path: String,
        names: LayoutNames
    ) {
        guard let original = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }

        var text = original

        for _ in 0..<maxPasses {
            let next = pass(LayoutSource(path: path, text: text), names: names)

            guard next != text else {
                break
            }

            text = next
        }

        if text != original {
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    static func pass(
        _ source: LayoutSource,
        names: LayoutNames
    ) -> String {
        let steps = [{ moved($0, names: names) }, split, merged, ordered, spaced]

        for step in steps {
            let edits = step(source)

            if !edits.isEmpty {
                return LayoutEdit.apply(edits, to: source.text)
            }
        }

        return source.text
    }

    static func spaced(_ source: LayoutSource) -> [LayoutEdit] {
        LayoutCommand.findings(in: source).compactMap(\.edit)
    }

    static func block(
        _ header: String,
        _ members: [String]
    ) -> String {
        let body = members.map { indent + $0 }.joined(separator: "\n\n")
        return "\(header) {\n\(body)\n}"
    }

    static func header(of node: ExtensionDeclSyntax) -> String {
        let start = node.positionAfterSkippingLeadingTrivia.utf8Offset
        let end = node.memberBlock.leftBrace.positionAfterSkippingLeadingTrivia.utf8Offset
        let bytes = Array(node.trimmedDescription.utf8).prefix(end - start)
        return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func texts(of members: [DeclSyntax]) -> [String] {
        members.map(\.trimmedDescription)
    }

    static func whole(_ node: some SyntaxProtocol) -> LayoutEdit {
        LayoutEdit(start: node.position.utf8Offset, end: node.endPosition.utf8Offset, text: "")
    }

    static func body(
        of node: some SyntaxProtocol,
        _ text: String
    ) -> LayoutEdit {
        LayoutEdit(
            start: node.positionAfterSkippingLeadingTrivia.utf8Offset,
            end: node.endPositionBeforeTrailingTrivia.utf8Offset,
            text: text
        )
    }
}
