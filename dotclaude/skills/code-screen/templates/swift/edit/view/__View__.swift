import Core
import __Models__
import SwiftUI

public struct __View__: View {
    @State private var model: __Screen__Model

    @FocusState private var isNameFocused: Bool

    @Environment(\.dismiss) private var dismiss

    private let onSave: (__Item__) -> Void

    public init(
        model: __Screen__Model,
        onSave: @escaping (__Item__) -> Void
    ) {
        _model = State(initialValue: model)

        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("名前", text: Bindable(model.state).name)
                .focused($isNameFocused)

            Text(model.state.failureMessage ?? "")

            buttons
        }
        .padding(16)
        .confirmationDialog(
            "保存せずに閉じますか",
            isPresented: Bindable(model.state).isConfirmingDiscard
        ) {
            Button("保存せずに閉じる", role: .destructive) {
                dismiss()
            }
        }
        .onOutcome(model.state.outcome) { item in
            onSave(item)
            dismiss()
        }
    }
}

private extension __View__ {
    var buttons: some View {
        HStack(spacing: 16) {
            Button("閉じる") {
                close()
            }

            Button("保存") {
                isNameFocused = false

                model.perform {
                    await $0.save()
                }
            }
            .disabled(!model.output.canSave)
        }
    }
}

private extension __View__ {
    func close() {
        if model.output.isChanged {
            model.state.isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }
}
