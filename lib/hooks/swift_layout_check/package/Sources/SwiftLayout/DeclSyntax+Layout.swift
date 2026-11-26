import SwiftSyntax

extension DeclSyntax {
    var isType: Bool {
        typeName != nil || self.is(TypeAliasDeclSyntax.self)
    }

    var typeName: String? {
        if let node = self.as(StructDeclSyntax.self) {
            return node.name.text
        }

        if let node = self.as(ClassDeclSyntax.self) {
            return node.name.text
        }

        if let node = self.as(EnumDeclSyntax.self) {
            return node.name.text
        }

        if let node = self.as(ActorDeclSyntax.self) {
            return node.name.text
        }

        return self.as(ProtocolDeclSyntax.self)?.name.text
    }

    var modifierNames: [String] {
        asProtocol(WithModifiersSyntax.self)?.modifiers.map(\.name.text) ?? []
    }

    var isClosed: Bool {
        modifierNames.contains("private") || modifierNames.contains("fileprivate")
    }

    var isOpen: Bool {
        modifierNames.contains("public") || modifierNames.contains("open")
            || modifierNames.contains("package")
    }

    var isLocal: Bool {
        var current = parent

        while let node = current {
            if node.is(CodeBlockSyntax.self) || node.is(ClosureExprSyntax.self) {
                return true
            }

            current = node.parent
        }

        return false
    }

    var isOverride: Bool {
        modifierNames.contains("override")
    }

    var isInheritable: Bool {
        self.is(ClassDeclSyntax.self) && !modifierNames.contains("final")
    }

    var isOverridable: Bool {
        let isComputed = self.as(VariableDeclSyntax.self).map { !$0.isStored } ?? false
        return self.is(FunctionDeclSyntax.self) || self.is(SubscriptDeclSyntax.self) || isComputed
    }

    var accessRank: Int? {
        if modifierNames.contains("public") || modifierNames.contains("open") {
            return 2
        }

        if modifierNames.contains("package") {
            return 1
        }

        if modifierNames.contains("internal") {
            return 0
        }

        return isClosed ? -1 : nil
    }

    var isPart: Bool {
        if let function = self.as(FunctionDeclSyntax.self) {
            return function.signature.returnClause?.type.isOpaque ?? false
        }

        return self.as(VariableDeclSyntax.self)?.isOpaque ?? false
    }

    var isBuilder: Bool {
        let attributes = asProtocol(WithAttributesSyntax.self)?.attributes
        let hasBuilder = attributes?.contains { $0.trimmedDescription.hasSuffix("Builder") }
        return isPart || hasBuilder == true
    }
}

extension TypeSyntax {
    var isOpaque: Bool {
        trimmedDescription.hasPrefix("some ")
    }
}
