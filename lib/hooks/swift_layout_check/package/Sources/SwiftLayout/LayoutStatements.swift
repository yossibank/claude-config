import SwiftSyntax

final class LayoutStatements: SyntaxVisitor {
    private(set) var findings: [LayoutFinding] = []

    private let source: LayoutSource

    private var builders = 0

    init(source: LayoutSource) {
        self.source = source

        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(DeclSyntax(node).isBuilder)
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        leave(DeclSyntax(node).isBuilder)
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(DeclSyntax(node).isBuilder)
    }

    override func visitPost(_ node: VariableDeclSyntax) {
        leave(DeclSyntax(node).isBuilder)
    }

    override func visit(_: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(true)
    }

    override func visitPost(_: MacroExpansionDeclSyntax) {
        leave(true)
    }

    override func visit(_: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        enter(true)
    }

    override func visitPost(_: MacroExpansionExprSyntax) {
        leave(true)
    }

    override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind {
        let isCode = builders == 0 && node.parent?.is(SourceFileSyntax.self) == false

        if isCode, let parent = node.parent, source.isMultiline(parent) {
            findings += check(Array(node))
        }

        return .visitChildren
    }
}

private extension LayoutStatements {
    enum Kind {
        case declaration
        case action
        case parent
        case exit
        case block
    }
}

private extension LayoutStatements {
    static let shortCount = 3

    func enter(_ isBuilder: Bool) -> SyntaxVisitorContinueKind {
        builders += isBuilder ? 1 : 0
        return .visitChildren
    }

    func leave(_ isBuilder: Bool) {
        builders -= isBuilder ? 1 : 0
    }

    func kind(of item: CodeBlockItemSyntax) -> Kind {
        if source.isMultiline(item) {
            return .block
        }

        if item.item.is(DeclSyntax.self) {
            return .declaration
        }

        if let statement = item.item.as(StmtSyntax.self), !statement.is(ExpressionStmtSyntax.self) {
            return .exit
        }

        return item.trimmedDescription.hasPrefix("super.") ? .parent : .action
    }

    func check(_ items: [CodeBlockItemSyntax]) -> [LayoutFinding] {
        let kinds = items.map(kind)
        let isInit = items.first?.parent?.parent?.parent?.is(InitializerDeclSyntax.self) == true
        let isPlain = !kinds.contains(.block) && !kinds.contains(.parent)

        if isPlain, !isInit, items.count <= Self.shortCount {
            return blanks(in: items, "L7: 1 行の文が 3 つまでのブロックには、空行を入れない")
        }

        if kinds.dropLast().allSatisfy({ $0 == .declaration }), kinds.last == .exit {
            return blanks(in: items, "L7: 1 行の let の並びと最後の return だけのブロックには、空行を入れない")
        }

        return zip(items, items.dropFirst()).enumerated().compactMap { index, pair in
            gap(pair.1, from: kinds[index], to: kinds[index + 1], isInit: isInit)
        }
    }

    func blanks(
        in items: [CodeBlockItemSyntax],
        _ message: String
    ) -> [LayoutFinding] {
        items.dropFirst().filter(source.hasBlankLine).map { source.finding(at: $0, message) }
    }

    func gap(
        _ item: CodeBlockItemSyntax,
        from before: Kind,
        to after: Kind,
        isInit: Bool
    ) -> LayoutFinding? {
        let hasBlank = source.hasBlankLine(before: item)

        if before == .block || after == .block {
            return hasBlank ? nil : source.finding(at: item, "L7: 複数行の文の前後には、空行を入れる")
        }

        if before != after {
            return hasBlank ? nil : source.finding(at: item, "L7: 段落（準備・実行・出口）が変わる所には、空行を入れる")
        }

        let isLoose = hasBlank && !isInit

        return isLoose ? source.finding(at: item, "L7: 同じ段落の 1 行の文の間に、空行を入れない") : nil
    }
}
