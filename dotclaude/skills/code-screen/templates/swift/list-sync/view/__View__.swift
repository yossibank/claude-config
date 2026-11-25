import Core
import __Models__
import SwiftUI

public struct __View__: View {
    @State private var model: __Screen__Model
    @State private var layout = Layout()

    @Environment(\.scenePhase) private var scenePhase

    private let onRemove: (__Item__) -> Void

    public init(
        model: __Screen__Model,
        onRemove: @escaping (__Item__) -> Void
    ) {
        _model = State(initialValue: model)

        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.input.items) { item in
                    row(item)
                }
            }
            .padding(.top, layout.headerHeight)
        }
        .overlay(alignment: .top) {
            header
        }
        .onAppear {
            model.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
            }
        }
        .onOutcome(model.state.outcome) { item in
            onRemove(item)
        }
    }
}

extension __View__ {
    struct Layout {
        var headerHeight: CGFloat = 0
    }
}

private extension __View__ {
    var header: some View {
        Text(model.state.failureMessage ?? emptyMessage)
            .frame(maxWidth: .infinity)
            .padding(16)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                layout.headerHeight = height
            }
    }

    var emptyMessage: String {
        model.output.isEmpty ? "まだありません" : ""
    }

    func row(_ item: __Item__) -> some View {
        HStack(spacing: 8) {
            Button(item.name) {
                model.state.editing = item
            }

            Spacer()

            Button("消す", role: .destructive) {
                model.remove(item)
            }
        }
        .padding(.horizontal, 16)
    }
}
