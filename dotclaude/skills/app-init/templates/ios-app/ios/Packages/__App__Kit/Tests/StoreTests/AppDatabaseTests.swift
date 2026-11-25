@testable import Store
import Testing

struct AppDatabaseTests {
    @Test
    func migratesInMemory() throws {
        let database = try AppDatabase.inMemory()

        let isMigrated = try database.writer.read { db in
            try AppDatabase.migrator.hasCompletedMigrations(db)
        }

        #expect(isMigrated)
    }

    @Test
    func listsAppliedMigrations() async throws {
        let database = try AppDatabase.inMemory()

        let migrations = try await database.appliedMigrations()

        #expect(migrations == ["v1"])
    }
}
