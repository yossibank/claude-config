import SwiftSyntax

extension DeclSyntax {
    var isType: Bool {
        self.is(StructDeclSyntax.self) || self.is(ClassDeclSyntax.self)
            || self.is(EnumDeclSyntax.self) || self.is(ActorDeclSyntax.self)
            || self.is(ProtocolDeclSyntax.self)
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

    var isOverride: Bool {
        modifierNames.contains("override")
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
