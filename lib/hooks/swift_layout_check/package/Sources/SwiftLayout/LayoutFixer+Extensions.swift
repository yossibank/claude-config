import SwiftSyntax

extension LayoutFixer {
    static func sections(of source: LayoutSource) -> [LayoutSection] {
        let declared = Set(source.tree.statements.compactMap { $0.item.as(DeclSyntax.self)?.typeName })

        return source.tree.statements.compactMap { item in
            item.item.as(DeclSyntax.self).flatMap { LayoutSection($0, declared: declared, in: source) }
        }
    }

    static func split(_ source: LayoutSource) -> [LayoutEdit] {
        sections(of: source).filter(\.mixesTypes).compactMap { section in
            guard let node = section.node.as(ExtensionDeclSyntax.self) else {
                return nil
            }

            let members = node.memberBlock.members.map(\.decl)
            let head = header(of: node)
            let types = block(head, texts(of: members.filter(\.isType)))
            let values = block(head, texts(of: members.filter { !$0.isType }))

            return body(of: node, types + "\n\n" + values)
        }
    }

    static func merged(_ source: LayoutSource) -> [LayoutEdit] {
        let extensions = sections(of: source).filter { section in
            section.node.is(ExtensionDeclSyntax.self) && section.slot != .conformance
        }

        let groups = Dictionary(grouping: extensions, by: \.roleKey).values

        return groups.flatMap { group in
            group.contains(where: \.hasParts) ? parted(group) : joined(group)
        }
    }

    static func joined(_ group: [LayoutSection]) -> [LayoutEdit] {
        guard group.count > 1, let first = group.first?.node.as(ExtensionDeclSyntax.self) else {
            return []
        }

        let members = group.flatMap(members)
        let rest = group.dropFirst().map { whole($0.node) }

        return [body(of: first, block(header(of: first), texts(of: members)))] + rest
    }

    static func parted(_ group: [LayoutSection]) -> [LayoutEdit] {
        let isBlended = group.contains { $0.hasParts && $0.hasActions }
        let isReversed = zip(group, group.dropFirst()).contains { !$0.hasParts && $1.hasParts }

        guard
            isBlended || isReversed || group.count > 2,
            let first = group.first?.node.as(ExtensionDeclSyntax.self)
        else {
            return []
        }

        let members = group.flatMap(members)
        let head = header(of: first)
        let parts = block(head, texts(of: members.filter(\.isPart)))
        let actions = members.filter { !$0.isPart }
        let text = actions.isEmpty ? parts : parts + "\n\n" + block(head, texts(of: actions))

        return [body(of: first, text)] + group.dropFirst().map { whole($0.node) }
    }

    static func members(of section: LayoutSection) -> [DeclSyntax] {
        section.node.as(ExtensionDeclSyntax.self)?.memberBlock.members.map(\.decl) ?? []
    }
}
