import SwiftSyntax

final class LayoutOutsiders: SyntaxVisitor {
    private(set) var owner: DeclSyntax?
    private(set) var members: [DeclSyntax] = []

    override func visit(_ node: MemberBlockSyntax) -> SyntaxVisitorContinueKind {
        guard owner == nil, let parent = node.parent?.as(DeclSyntax.self), isOwner(parent) else {
            return owner == nil ? .visitChildren : .skipChildren
        }

        let found = node.members.map(\.decl).filter { LayoutMembers.outsider($0) != nil }

        if !found.isEmpty {
            owner = parent
            members = found
        }

        return .visitChildren
    }
}

private extension LayoutOutsiders {
    func isOwner(_ node: DeclSyntax) -> Bool {
        let members = node.asProtocol(DeclGroupSyntax.self)?.memberBlock.members.map(\.decl) ?? []
        let isNamespace = node.is(EnumDeclSyntax.self) && !members.contains { $0.is(EnumCaseDeclSyntax.self) }
        return node.typeName != nil && !node.is(ProtocolDeclSyntax.self) && !isNamespace && !node.isLocal
    }
}
