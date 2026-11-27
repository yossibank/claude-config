import DesignSystem
import FeatureModels
import SwiftUI

public struct HomeView: View {
    @State private var model: HomeModel
    @State private var layout = Layout()

    public init(model: HomeModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                Text("__DisplayName__")
                    .font(.title)

                status

                Button("読み直す") {
                    model.perform {
                        await $0.load()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.medium)
        }
        .scrollPosition($layout.position)
        .task {
            await model.load()
        }
        .onOutcome(model.state.outcome) { _ in
            layout.position.scrollTo(edge: .top)
        }
    }
}

extension HomeView {
    struct Layout {
        var position = ScrollPosition(edge: .top)
    }
}

private extension HomeView {
    @ViewBuilder
    var status: some View {
        if let message = model.state.notices.error.message {
            Text(message)
        } else if model.output.isLoaded {
            Text("データの版 \(model.output.schemaVersion)")
        } else if !model.output.isFailed {
            ProgressView()
        }
    }
}

#Preview {
    if let parts = ScreenParts.preview() {
        HomeView(model: HomeModel(parts: parts))
    }
}
