import Foundation

public struct ScreenClock: Sendable {
    private let current: @Sendable () -> Date

    public init(_ current: @escaping @Sendable () -> Date) {
        self.current = current
    }
}

public extension ScreenClock {
    static let system = ScreenClock {
        Date()
    }

    var now: Date {
        current()
    }

    static func fixed(_ date: Date) -> ScreenClock {
        ScreenClock {
            date
        }
    }
}
