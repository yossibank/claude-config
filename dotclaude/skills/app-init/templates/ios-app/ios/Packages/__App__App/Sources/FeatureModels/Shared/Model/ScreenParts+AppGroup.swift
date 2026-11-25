import Store

public extension ScreenParts {
    static func appGroup(clock: ScreenClock) async throws -> ScreenParts {
        let database = try AppDatabase.appGroup()
        return ScreenParts(database: database, clock: clock)
    }
}
