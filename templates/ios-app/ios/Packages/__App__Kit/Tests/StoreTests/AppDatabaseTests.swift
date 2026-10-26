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
}
