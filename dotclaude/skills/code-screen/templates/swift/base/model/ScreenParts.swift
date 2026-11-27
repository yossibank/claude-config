import Store

public struct ScreenParts: Sendable {
    public let clock: ScreenClock
    public let wait: ScreenWait

    let database: AppDatabase

    public init(
        database: AppDatabase,
        clock: ScreenClock,
        wait: ScreenWait = .system
    ) {
        self.database = database
        self.clock = clock
        self.wait = wait
    }
}
