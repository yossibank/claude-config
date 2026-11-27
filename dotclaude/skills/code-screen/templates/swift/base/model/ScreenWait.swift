public struct ScreenWait: Sendable {
    private let sleep: @Sendable (Duration) async throws -> Void

    public init(_ sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.sleep = sleep
    }
}

public extension ScreenWait {
    static let system = ScreenWait { duration in
        try await Task.sleep(for: duration)
    }

    @MainActor
    @discardableResult
    func after(
        _ duration: Duration,
        perform action: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            guard await (try? sleep(duration)) != nil, !Task.isCancelled else {
                return
            }

            action()
        }
    }
}
