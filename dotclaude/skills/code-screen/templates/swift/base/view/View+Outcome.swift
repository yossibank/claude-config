import __Models__
import SwiftUI

public extension View {
    func onOutcome<Value>(
        _ outcome: ScreenOutcome<Value>,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        onChange(of: outcome) { _, outcome in
            if let value = outcome.value {
                action(value)
            }
        }
    }
}
