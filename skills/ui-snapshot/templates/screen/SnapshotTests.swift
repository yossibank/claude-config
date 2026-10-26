@testable import DesignSystem
import SwiftUI
import Testing
import UIKit

@MainActor
struct SnapshotTests {
    @Test
    func render() throws {
        for item in Self.cases {
            for scheme in [ColorScheme.light, .dark] {
                let view = item.view()
                    .frame(width: item.size.width, height: item.size.height)
                    .background(Color(uiColor: .systemBackground))
                    .environment(\.colorScheme, scheme)

                try Self.write(view, to: "\(item.name)-\(scheme == .dark ? "dark" : "light").png")
            }
        }
    }
}

extension SnapshotTests {
    struct Case {
        let name: String
        let size: CGSize
        let view: () -> AnyView
    }
}

private extension SnapshotTests {
    static let directory = "__OUT__"

    static let phone = CGSize(width: 393, height: 852)

    static let cases: [Case] = [
        Case(name: "sample", size: phone) {
            AnyView(Text("sample"))
        }
    ]

    static func write(
        _ view: some View,
        to name: String
    ) throws {
        let renderer = ImageRenderer(content: view)

        renderer.scale = 2

        let data = try #require(renderer.uiImage?.pngData())
        let url = URL(fileURLWithPath: directory).appending(path: name)

        try data.write(to: url)
    }
}
