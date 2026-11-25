import Store

public extension ScreenParts {
    static func preview() -> ScreenParts? {
        guard let database = try? AppDatabase.inMemory() else {
            return nil
        }

        return ScreenParts(database: database, clock: .system)
    }
}
