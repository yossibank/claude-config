import SwiftSyntax

final class LayoutQualifier: SyntaxVisitor {
    private(set) var edits: [LayoutEdit] = []

    private let scope: [String: String]
    private let start: Int

    init(
        scope: [String: String],
        start: Int
    ) {
        self.scope = scope
        self.start = start

        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        qualify(node.name)
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let isMember = node.parent?.as(MemberAccessExprSyntax.self)?.declName.id == node.id

        if !isMember {
            qualify(node.baseName)
        }

        return .visitChildren
    }
}

private extension LayoutQualifier {
    func qualify(_ token: TokenSyntax) {
        guard let parent = scope[token.text] else {
            return
        }

        let offset = token.positionAfterSkippingLeadingTrivia.utf8Offset - start

        edits.append(LayoutEdit(start: offset, end: offset, text: parent + "."))
    }
}
