import Store

public struct ScreenParts: Sendable {
    public let clock: ScreenClock

    let database: AppDatabase

    public init(
        database: AppDatabase,
        clock: ScreenClock
    ) {
        self.database = database
        self.clock = clock
    }
}
