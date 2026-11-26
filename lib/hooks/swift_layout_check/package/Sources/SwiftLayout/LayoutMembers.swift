import SwiftSyntax

final class LayoutMembers: SyntaxVisitor {
    private(set) var findings: [LayoutFinding] = []

    private let source: LayoutSource

    init(source: LayoutSource) {
        self.source = source

        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MemberBlockSyntax) -> SyntaxVisitorContinueKind {
        let members = node.members.map(\.decl)

        if let owner = node.parent?.as(DeclSyntax.self) {
            findings += depth(of: owner) + conformance(of: owner) + body(of: owner, members)
        }

        findings += spacing(of: members) + length(of: members)

        return .visitChildren
    }
}

extension LayoutMembers {
    static let maxDepth = 3
    static let maxLines = 60

    static let entryPoints: Set<String> = [
        "body",
        "makeBody",
        "makeUIView",
        "path",
        "placeSubviews",
        "reduce",
        "sizeThatFits",
        "updateUIView"
    ]

    func depth(of owner: DeclSyntax) -> [LayoutFinding] {
        guard owner.typeName != nil else {
            return []
        }

        var depth = 0
        var current: Syntax? = Syntax(owner)

        while let node = current {
            if let parent = node.as(ExtensionDeclSyntax.self) {
                depth += parent.extendedType.trimmedDescription.split(separator: ".").count
            } else if node.as(DeclSyntax.self)?.typeName != nil {
                depth += 1
            }

            current = node.parent
        }

        return depth > Self.maxDepth ? [source.finding(at: owner, "L4: 入れ子の型は 2 段までにする")] : []
    }

    func conformance(of owner: DeclSyntax) -> [LayoutFinding] {
        guard
            let node = owner.as(ExtensionDeclSyntax.self),
            let inherited = node.inheritanceClause?.inheritedTypes,
            inherited.count > 1,
            !node.memberBlock.members.isEmpty
        else {
            return []
        }

        return [source.finding(at: owner, "L5: 実装のある適合は、1 つの適合につき 1 つの extension に分ける")]
    }

    func body(
        of owner: DeclSyntax,
        _ members: [DeclSyntax]
    ) -> [LayoutFinding] {
        let isNamespace = owner.is(EnumDeclSyntax.self) && !members.contains { $0.is(EnumCaseDeclSyntax.self) }

        guard owner.typeName != nil, !owner.is(ProtocolDeclSyntax.self), !isNamespace, !owner.isLocal else {
            return []
        }

        return members.compactMap { member in
            Self.outsider(member).map {
                source.finding(at: member, "L3: 型の本体には、保存プロパティ・case・init だけを置く。\($0) は extension に出す")
            }
        }
    }

    static func outsider(_ member: DeclSyntax) -> String? {
        if member.isOverride {
            return nil
        }

        if let function = member.as(FunctionDeclSyntax.self) {
            return Self.entryPoints.contains(function.name.text) ? nil : function.name.text
        }

        if let variable = member.as(VariableDeclSyntax.self) {
            let isKept = variable.isStored || variable.names == ["body"]
            return isKept ? nil : variable.names.joined(separator: "・")
        }

        if let name = member.typeName {
            return name == "CodingKeys" ? nil : name
        }

        return member.is(SubscriptDeclSyntax.self) ? "subscript" : nil
    }

    func spacing(of members: [DeclSyntax]) -> [LayoutFinding] {
        zip(members, members.dropFirst()).compactMap { before, after in
            let hasBlank = source.hasBlankLine(before: after)
            let isMultiline = source.isMultiline(before) || source.isMultiline(after)

            if isMultiline {
                return hasBlank ? sandwiched(before, after) : source.finding(at: after, "L6: 複数行の宣言の前後には、空行を入れる", blank: true)
            }

            guard hasBlank, let group = storedGroup(of: before), group == storedGroup(of: after) else {
                return nil
            }

            return source.finding(at: after, "L6: 同じまとまりの 1 行の宣言の間に、空行を入れない", blank: false)
        }
    }

    func sandwiched(
        _ before: DeclSyntax,
        _ after: DeclSyntax
    ) -> LayoutFinding? {
        guard
            source.isMultiline(before),
            !source.isMultiline(after),
            let group = storedGroup(of: before),
            group == storedGroup(of: after)
        else {
            return nil
        }

        return source.finding(at: after, "L6: 1 行の宣言は、同じまとまりの複数行の宣言より前に置く")
    }

    func storedGroup(of member: DeclSyntax) -> String? {
        guard let variable = member.as(VariableDeclSyntax.self), variable.isStored else {
            return nil
        }

        return variable.group
    }

    func length(of members: [DeclSyntax]) -> [LayoutFinding] {
        members.compactMap { member in
            let isCode = member.is(FunctionDeclSyntax.self) || member.is(InitializerDeclSyntax.self)
                || member.as(VariableDeclSyntax.self)?.isStored == false

            guard isCode, source.lineCount(of: member) > Self.maxLines else {
                return nil
            }

            return source.finding(at: member, "L8: 1 つの関数は \(Self.maxLines) 行までにする")
        }
    }
}
