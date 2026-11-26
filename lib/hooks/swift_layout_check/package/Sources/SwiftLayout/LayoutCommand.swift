import Foundation

@main
enum LayoutCommand {
    static func main() {
        for path in CommandLine.arguments.dropFirst() {
            guard let source = LayoutSource(path: path) else {
                continue
            }

            for finding in findings(in: source) {
                print("\(path):\(finding.line): \(finding.message)")
            }
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
