import SwiftSyntax

enum LayoutSections {
    static func findings(in source: LayoutSource) -> [LayoutFinding] {
        let declared = Set(source.tree.statements.compactMap { $0.item.as(DeclSyntax.self)?.typeName })

        let sections = source.tree.statements.compactMap { item in
            item.item.as(DeclSyntax.self).flatMap { LayoutSection($0, declared: declared, in: source) }
        }

        return order(of: sections, in: source) + roles(of: sections, in: source)
    }

    private static func order(
        of sections: [LayoutSection],
        in source: LayoutSource
    ) -> [LayoutFinding] {
        var latest: [String: LayoutSection] = [:]
        var nested: [String: Int] = [:]
        var findings: [LayoutFinding] = []

        for section in sections where section.slot.isOwn {
            let isLate = section.slot == .nested && nested[section.path, default: 0] > section.access

            if let before = latest[section.owner], before.rank > section.rank {
                let message = "L1: extension の順が違う。「\(section.slot.title)」は「\(before.slot.title)」より前に置く"
                findings.append(source.finding(at: section.node, message))
            } else if isLate {
                findings.append(source.finding(at: section.node, "L1: extension は public・無印・private の順に置く"))
            } else {
                latest[section.owner] = section
                nested[section.path] = section.access
            }
        }

        return findings + misplaced(sections, in: source)
    }

    private static func misplaced(
        _ sections: [LayoutSection],
        in source: LayoutSource
    ) -> [LayoutFinding] {
        let lastOwn = sections.lastIndex { $0.slot.isOwn }

        let foreign = sections.enumerated().filter { index, section in
            section.slot == .foreign && index < lastOwn ?? 0
        }

        let items = Array(source.tree.statements)
        let firstPreview = items.firstIndex(where: isPreview) ?? items.endIndex
        let late = items.dropFirst(firstPreview).filter { !isPreview($0) }

        return foreign.map { source.finding(at: $0.element.node, "L1: ほかの型の extension は、このファイルの型の後に置く") }
            + late.map { source.finding(at: $0, "L1: #Preview は、ファイルの最後に置く") }
    }

    private static func isPreview(_ item: CodeBlockItemSyntax) -> Bool {
        let name = item.item.as(MacroExpansionDeclSyntax.self)?.macroName.text
            ?? item.item.as(MacroExpansionExprSyntax.self)?.macroName.text

        return name == "Preview"
    }

    private static func roles(
        of sections: [LayoutSection],
        in source: LayoutSource
    ) -> [LayoutFinding] {
        let extensions = sections.filter { $0.node.is(ExtensionDeclSyntax.self) }

        let mixed = extensions.filter(\.mixesTypes).map {
            source.finding(at: $0.node, "L2: 入れ子の型の宣言と、値・関数を同じ extension に置かない。extension を分ける")
        }

        let groups = Dictionary(grouping: extensions.filter { $0.slot != .conformance }, by: \.roleKey)

        let repeated = groups.values.flatMap { group in
            group.contains(where: \.hasParts) ? parts(of: group, in: source) : duplicates(of: group, in: source)
        }

        return mixed + repeated
    }

    private static func duplicates(
        of group: [LayoutSection],
        in source: LayoutSource
    ) -> [LayoutFinding] {
        group.dropFirst().map {
            source.finding(at: $0.node, "L2: 同じ役割の extension が 2 つある。1 つにまとめる")
        }
    }

    private static func parts(
        of group: [LayoutSection],
        in source: LayoutSource
    ) -> [LayoutFinding] {
        let message = "L2: 画面の部品と処理を、別の private extension に分ける。部品を先に置く"
        let blended = group.filter { $0.hasParts && $0.hasActions }
        let ordered = zip(group, group.dropFirst()).filter { !$0.hasParts && $1.hasParts }.map(\.1)
        let extra = group.count > 2 ? duplicates(of: Array(group.dropFirst()), in: source) : []
        return (blended + ordered).map { source.finding(at: $0.node, message) } + extra
    }
}
