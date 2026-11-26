import SwiftSyntax

final class LayoutNames: SyntaxVisitor {
    private(set) var nested: [String: Set<String>] = [:]

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        note(node.name.text, in: Syntax(node))
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        note(node.name.text, in: Syntax(node))
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        note(node.name.text, in: Syntax(node))
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        note(node.name.text, in: Syntax(node))
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        note(node.name.text, in: Syntax(node))
    }
}

extension LayoutNames {
    func scope(of path: String) -> [String: String] {
        let parts = path.split(separator: ".").map(String.init)
        let own = nested[path] ?? []
        var scope: [String: String] = [:]

        for count in 1..<max(parts.count, 1) {
            let parent = parts.prefix(count).joined(separator: ".")

            for name in nested[parent] ?? [] where !own.contains(name) {
                scope[name] = parent
            }
        }

        return scope
    }
}

private extension LayoutNames {
    func note(
        _ name: String,
        in node: Syntax
    ) -> SyntaxVisitorContinueKind {
        var names: [String] = []
        var current = node.parent

        while let syntax = current {
            if let parent = syntax.as(ExtensionDeclSyntax.self) {
                names.insert(parent.extendedType.trimmedDescription.replacing(/<.*>/, with: ""), at: 0)
            } else if let parent = syntax.as(DeclSyntax.self)?.typeName {
                names.insert(parent, at: 0)
            }

            current = syntax.parent
        }

        if !names.isEmpty {
            nested[names.joined(separator: "."), default: []].insert(name)
        }

        return .visitChildren
    }
}
