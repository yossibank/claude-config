import SwiftSyntax

private extension LayoutFixer {
    struct Key: Equatable {
        let bucket: Int
        let owner: String
        let rank: Int
        let path: String
        let access: Int
    }
}

extension LayoutFixer {
    static func ordered(_ source: LayoutSource) -> [LayoutEdit] {
        let items = Array(source.tree.statements).filter { !$0.item.is(ImportDeclSyntax.self) }
        let declared = Set(source.tree.statements.compactMap { $0.item.as(DeclSyntax.self)?.typeName })
        let isPlain = items.allSatisfy { $0.leadingTrivia.description.allSatisfy(\.isWhitespace) }

        let keys = items.map { item in
            key(of: item, declared: declared, in: source)
        }

        guard isPlain, !keys.contains(where: { $0 == nil }), let first = items.first, let last = items.last else {
            return []
        }

        let ranked = rank(keys.compactMap { $0 })
        let order = ranked.indices.sorted { ranked[$0].lexicographicallyPrecedes(ranked[$1]) }

        guard order != Array(ranked.indices) else {
            return []
        }

        let texts = items.map(\.trimmedDescription)
        let text = order.map { texts[$0] }.joined(separator: "\n\n")

        return [
            LayoutEdit(
                start: first.positionAfterSkippingLeadingTrivia.utf8Offset,
                end: last.endPositionBeforeTrailingTrivia.utf8Offset,
                text: text
            )
        ]
    }
}

private extension LayoutFixer {
    static func key(
        of item: CodeBlockItemSyntax,
        declared: Set<String>,
        in source: LayoutSource
    ) -> Key? {
        let macro = item.item.as(MacroExpansionDeclSyntax.self)?.macroName.text
            ?? item.item.as(MacroExpansionExprSyntax.self)?.macroName.text

        if macro == "Preview" {
            return Key(bucket: 2, owner: "", rank: 0, path: "", access: 0)
        }

        guard
            let node = item.item.as(DeclSyntax.self),
            let section = LayoutSection(node, declared: declared, in: source)
        else {
            return nil
        }

        guard section.slot.isOwn else {
            return Key(bucket: 1, owner: "", rank: 0, path: "", access: 0)
        }

        let isNested = section.slot == .nested

        return Key(
            bucket: 0,
            owner: section.owner,
            rank: section.rank,
            path: isNested ? section.path : "",
            access: isNested ? section.access : 0
        )
    }

    static func rank(_ keys: [Key]) -> [[Int]] {
        let owners = first(of: keys.map(\.owner))
        let paths = first(of: keys.map(\.path))

        return keys.enumerated().map { index, key in
            [key.bucket, owners[key.owner] ?? 0, key.rank, paths[key.path] ?? 0, key.access, index]
        }
    }

    static func first(of names: [String]) -> [String: Int] {
        var seen: [String: Int] = [:]

        for (index, name) in names.enumerated() where seen[name] == nil {
            seen[name] = index
        }

        return seen
    }
}
