import Observation

@MainActor
@Observable
public final class ErrorNotice {
    public private(set) var message: String?

    @ObservationIgnored private var count = 0
    @ObservationIgnored private var timer: Task<Void, Never>?

    @ObservationIgnored private let wait: ScreenWait

    public init(wait: ScreenWait) {
        self.wait = wait
    }
}

public extension ErrorNotice {
    nonisolated static var duration: Duration {
        .seconds(6)
    }

    func show(_ message: String) {
        self.message = message
        count += 1

        let count = count

        timer?.cancel()

        timer = wait.after(Self.duration) { [weak self] in
            guard let self, self.count == count else {
                return
            }

            clear()
        }
    }

    func clear() {
        timer?.cancel()
        timer = nil
        message = nil
    }
}
