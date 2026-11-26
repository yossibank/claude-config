import SwiftSyntax

private extension LayoutFixer {
    struct Group {
        let head: String

        var members: [String]
    }
}

extension LayoutFixer {
    static func moved(
        _ source: LayoutSource,
        names: LayoutNames
    ) -> [LayoutEdit] {
        let finder = LayoutOutsiders(viewMode: .sourceAccurate)

        finder.walk(source.tree)

        guard
            let owner = finder.owner,
            let home = top(of: owner),
            let path = path(of: owner)
        else {
            return []
        }

        let column = source.converter.location(for: owner.positionAfterSkippingLeadingTrivia).column - 1
        let scope = names.scope(of: path)
        let groups = grouped(finder.members, depth: column + indent.count, scope: scope)

        guard !groups.isEmpty else {
            return []
        }

        let attributes = owner.asProtocol(WithAttributesSyntax.self)?.attributes.map(\.trimmedDescription) ?? []
        let marks = attributes.filter { $0.hasPrefix("@available") }.map { $0 + "\n" }.joined()
        let text = groups.map { "\n\n" + marks + block($0.head + " " + path, $0.members) }.joined()
        let added = LayoutEdit(start: home.endPosition.utf8Offset, end: home.endPosition.utf8Offset, text: text)

        return finder.members.map(whole) + [added]
    }
}

private extension LayoutFixer {
    static let heads = ["public extension", "extension", "private extension"]

    static func top(of node: DeclSyntax) -> Syntax? {
        var current = Syntax(node)

        while let parent = current.parent {
            if parent.is(CodeBlockItemListSyntax.self), parent.parent?.is(SourceFileSyntax.self) == true {
                return current
            }

            current = parent
        }

        return nil
    }

    static func path(of node: DeclSyntax) -> String? {
        var names: [String] = []
        var current: Syntax? = Syntax(node)

        while let syntax = current {
            if let parent = syntax.as(ExtensionDeclSyntax.self) {
                guard parent.genericWhereClause == nil else {
                    return nil
                }

                names.insert(parent.extendedType.trimmedDescription.replacing(/<.*>/, with: ""), at: 0)
            } else if let name = syntax.as(DeclSyntax.self)?.typeName {
                names.insert(name, at: 0)
            }

            current = syntax.parent
        }

        return names.joined(separator: ".")
    }

    static func grouped(
        _ members: [DeclSyntax],
        depth: Int,
        scope: [String: String]
    ) -> [Group] {
        var types = heads.map { Group(head: $0, members: []) }
        var values = types

        for member in members {
            let slot = member.isOpen ? 0 : member.isClosed ? 2 : 1

            guard let text = shifted(hoisted(member, scope: scope), by: depth - indent.count) else {
                return []
            }

            if member.isType {
                types[slot].members.append(text)
            } else {
                values[slot].members.append(text)
            }
        }

        return (types + values).filter { !$0.members.isEmpty }
    }

    static func hoisted(
        _ member: DeclSyntax,
        scope: [String: String]
    ) -> String {
        let access: Set<String> = ["public", "private", "fileprivate"]
        let modifiers = member.asProtocol(WithModifiersSyntax.self)?.modifiers
        let modifier = modifiers?.first { access.contains($0.name.text) && $0.detail == nil }
        let start = member.positionAfterSkippingLeadingTrivia.utf8Offset
        let qualifier = LayoutQualifier(scope: scope, start: start)

        qualifier.walk(member)

        let dropped = modifier.map { modifier in
            LayoutEdit(
                start: modifier.positionAfterSkippingLeadingTrivia.utf8Offset - start,
                end: modifier.endPosition.utf8Offset - start,
                text: ""
            )
        }

        return LayoutEdit.apply(qualifier.edits + [dropped].compactMap { $0 }, to: member.trimmedDescription)
    }

    static func shifted(
        _ text: String,
        by count: Int
    ) -> String? {
        let prefix = String(repeating: " ", count: count)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let isAligned = lines.dropFirst().allSatisfy { $0.isEmpty || $0.hasPrefix(prefix) }

        guard isAligned else {
            return nil
        }

        let rest = lines.dropFirst().map { String($0.dropFirst(count)) }

        return ([String(lines[0])] + rest).joined(separator: "\n")
    }
}
