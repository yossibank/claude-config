import SwiftSyntax

struct LayoutSection {
    let node: DeclSyntax
    let slot: Slot
    let owner: String
    let path: String
    let access: Int

    init?(
        _ node: DeclSyntax,
        declared: Set<String>,
        in source: LayoutSource
    ) {
        if let name = node.typeName {
            self.init(node: node, slot: .body, owner: name, path: name)
        } else if let node = node.as(ExtensionDeclSyntax.self) {
            self.init(node, declared: declared, subject: source.subject)
        } else {
            return nil
        }
    }
}

extension LayoutSection {
    enum Slot: Int {
        case body = 2
        case types
        case members
        case closed
        case nested
        case conformance
        case foreign
    }
}

extension LayoutSection {
    var rank: Int {
        let isRanked = slot == .types || slot == .members
        return isRanked ? slot.rawValue * 10 + access : slot.rawValue * 10
    }

    var roleKey: String {
        let clause = node.as(ExtensionDeclSyntax.self)?.genericWhereClause?.trimmedDescription ?? ""
        return "\(path) \(slot.rawValue) \(access) \(clause)"
    }

    var mixesTypes: Bool {
        members.contains(where: \.isType) && members.contains { !$0.isType }
    }

    var hasParts: Bool {
        slot == .closed && members.contains(where: \.isPart)
    }

    var hasActions: Bool {
        members.contains { !$0.isPart }
    }
}

private extension LayoutSection {
    var members: [DeclSyntax] {
        node.as(ExtensionDeclSyntax.self)?.memberBlock.members.map(\.decl) ?? []
    }

    init(
        node: DeclSyntax,
        slot: Slot,
        owner: String,
        path: String
    ) {
        let access = node.isOpen ? 0 : node.isClosed ? 2 : 1

        self.node = node
        self.slot = slot
        self.owner = owner
        self.path = path
        self.access = access
    }

    init(
        _ node: ExtensionDeclSyntax,
        declared: Set<String>,
        subject: String
    ) {
        let name = node.extendedType.trimmedDescription.replacing(/<.*>/, with: "")
        let names = name.split(separator: ".").map(String.init)
        let depth = Self.ownDepth(of: names, declared: declared, subject: subject)
        let decl = DeclSyntax(node)

        guard let depth else {
            self.init(node: decl, slot: .foreign, owner: "", path: name)
            return
        }

        let owner = names.prefix(depth).joined(separator: ".")
        let members = node.memberBlock.members.map(\.decl)
        let hasOnlyTypes = !members.isEmpty && members.allSatisfy(\.isType)

        let slot: Slot = if node.inheritanceClause != nil {
            .conformance
        } else if names.count > depth {
            .nested
        } else if hasOnlyTypes {
            .types
        } else {
            decl.isClosed ? .closed : .members
        }

        self.init(node: decl, slot: slot, owner: owner, path: name)
    }

    static func ownDepth(
        of names: [String],
        declared: Set<String>,
        subject: String
    ) -> Int? {
        if let first = names.first, declared.contains(first) {
            return 1
        }

        return names.indices.map { $0 + 1 }.first { names.prefix($0).joined() == subject }
    }
}

extension LayoutSection.Slot {
    var isOwn: Bool {
        rawValue < Self.foreign.rawValue
    }

    var title: String {
        switch self {
        case .body: "型の本体"
        case .types: "入れ子の型の宣言"
        case .members: "外に見せる値と関数"
        case .closed: "private extension"
        case .nested: "入れ子の型の中身"
        case .conformance: "適合"
        case .foreign: "ほかの型の extension"
        }
    }
}
