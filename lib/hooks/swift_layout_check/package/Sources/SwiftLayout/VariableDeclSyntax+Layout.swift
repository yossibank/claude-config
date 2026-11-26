import SwiftSyntax

extension VariableDeclSyntax {
    var names: [String] {
        bindings.map(\.pattern.trimmedDescription)
    }

    var isOpaque: Bool {
        bindings.contains { $0.typeAnnotation?.type.isOpaque ?? false }
    }

    var isStored: Bool {
        bindings.allSatisfy { binding in
            switch binding.accessorBlock?.accessors {
            case nil:
                true

            case .getter:
                false

            case let .accessors(list):
                list.allSatisfy { Self.observers.contains($0.accessorSpecifier.text) }
            }
        }
    }

    var group: String {
        let attributes = attributes.map { $0.trimmedDescription.split(separator: "(").first ?? "" }
        let modifiers = modifiers.map(\.trimmedDescription)
        let parts = attributes.map(String.init) + modifiers + [bindingSpecifier.text]
        return parts.joined(separator: " ")
    }
}

private extension VariableDeclSyntax {
    static let observers: Set<String> = ["willSet", "didSet"]
}
