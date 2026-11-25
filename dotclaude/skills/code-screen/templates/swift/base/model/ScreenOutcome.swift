public struct ScreenOutcome<Value> {
    public private(set) var value: Value?

    private var round = 0

    public init() {}
}

public extension ScreenOutcome {
    mutating func send(_ value: Value) {
        self.value = value
        round &+= 1
    }
}

extension ScreenOutcome: Equatable {
    public static func == (
        lhs: ScreenOutcome,
        rhs: ScreenOutcome
    ) -> Bool {
        lhs.round == rhs.round
    }
}

extension ScreenOutcome: Sendable where Value: Sendable {}
