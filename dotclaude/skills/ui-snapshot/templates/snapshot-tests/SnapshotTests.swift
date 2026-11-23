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

                try Self.write(
                    view,
                    to: "\(item.name)-\(scheme == .dark ? "dark" : "light").png",
                    title: item.title,
                    variant: scheme == .dark ? "ダーク" : "ライト"
                )
            }
        }
    }
}

extension SnapshotTests {
    struct Case {
        let name: String
        /// 人が読む画面の名前。「設定 › 口座の編集」のように、画面と場合を › で区切る
        let title: String
        let size: CGSize
        let view: () -> AnyView
    }
}

private extension SnapshotTests {
    static let directory = "__OUT__"

    static let phone = CGSize(width: 393, height: 852)

    static let cases: [Case] = [
        Case(name: "sample", title: "見本", size: phone) {
            AnyView(Text("sample"))
        }
    ]

    static func write(
        _ view: some View,
        to name: String,
        title: String,
        variant: String
    ) throws {
        let renderer = ImageRenderer(content: view)

        renderer.scale = 2

        let data = try #require(renderer.uiImage?.pngData())
        let url = URL(fileURLWithPath: directory).appending(path: name)

        try data.write(to: url)
        try SnapshotIndex.record(directory: directory, file: name, title: title, variant: variant)
    }
}
