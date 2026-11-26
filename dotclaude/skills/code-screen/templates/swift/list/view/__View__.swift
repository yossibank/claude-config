import Core
import __Models__
import SwiftUI

public struct __View__: View {
    @State private var model: __Screen__Model
    @State private var layout = Layout()

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
                ForEach(model.output.items) { item in
                    row(item)
                }
            }
            .padding(.top, layout.headerHeight)
        }
        .overlay(alignment: .top) {
            header
        }
        .task {
            await model.run()
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
        Text(model.state.failureMessage ?? "")
            .frame(maxWidth: .infinity)
            .padding(16)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                layout.headerHeight = height
            }
    }

    func row(_ item: __Item__) -> some View {
        HStack(spacing: 8) {
            Button(item.name) {
                model.state.editing.show(item.id)
            }

            Spacer()

            Button("消す", role: .destructive) {
                model.perform {
                    await $0.remove(item)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
