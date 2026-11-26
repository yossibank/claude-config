import Foundation

@main
enum LayoutCommand {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let fixes = arguments.first == "--fix"
        let paths = Array(arguments.dropFirst(fixes ? 1 : 0))
        let names = LayoutNames(viewMode: .sourceAccurate)

        if fixes {
            paths.compactMap(LayoutSource.init).forEach { names.walk($0.tree) }
        }

        for path in paths {
            if fixes {
                LayoutFixer.fix(path: path, names: names)
            } else if let source = LayoutSource(path: path) {
                report(source, path: path)
            }
        }
    }

    static func report(
        _ source: LayoutSource,
        path: String
    ) {
        for finding in findings(in: source) {
            print("\(path):\(finding.line): \(finding.message)")
        }
    }

    static func findings(in source: LayoutSource) -> [LayoutFinding] {
        let members = LayoutMembers(source: source)
        let statements = LayoutStatements(source: source)

        members.walk(source.tree)
        statements.walk(source.tree)

        let all = LayoutSections.findings(in: source) + members.findings + statements.findings

        return all.sorted { $0.line < $1.line }
    }
}
