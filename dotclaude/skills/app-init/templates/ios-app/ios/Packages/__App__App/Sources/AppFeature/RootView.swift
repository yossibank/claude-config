import FeatureModels
import Features
import SwiftUI

public struct RootView: View {
    @State private var model = AppModel {
        try await ScreenParts.appGroup(clock: .system)
    }

    public init() {}

    public var body: some View {
        content
            .task {
                await model.open()
            }
    }
}

private extension RootView {
    @ViewBuilder
    var content: some View {
        switch model.state.launch {
        case .opening:
            ProgressView()

        case let .ready(home):
            HomeView(model: home)

        case .failed:
            ContentUnavailableView {
                Label("データを開けませんでした", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("もう一度試す") {
                    model.perform {
                        await $0.retryOpen()
                    }
                }
            }
        }
    }
}
