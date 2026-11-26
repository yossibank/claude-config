import Observation

@MainActor
@Observable
public final class ModelTask {
    private var running = 0

    public init() {}
}

public extension ModelTask {
    var isRunning: Bool {
        running > 0
    }

    @discardableResult
    func attempt<Value>(_ action: @MainActor () async throws -> Value) async rethrows -> Value {
        running += 1

        defer {
            running -= 1
        }

        return try await action()
    }
}
