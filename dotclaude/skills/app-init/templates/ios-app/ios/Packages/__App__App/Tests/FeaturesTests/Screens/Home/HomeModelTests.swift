import FeatureModels
import Foundation
import Store
import Testing

@MainActor
struct HomeModelTests {
    @Test
    func showsNothingBeforeLoading() throws {
        let setup = try Setup()
        let model = HomeModel(parts: setup.parts)

        #expect(!model.output.isLoaded)
        #expect(model.output.schemaVersion == 0)
        #expect(model.state.outcome.value == nil)
    }

    @Test
    func loadsSchemaVersionAndSendsOutcome() async throws {
        let setup = try Setup()
        let model = HomeModel(parts: setup.parts)

        await model.perform {
            await $0.load()
        }.value

        #expect(model.output.isLoaded)
        #expect(model.output.schemaVersion == 1)
        #expect(model.state.failureMessage == nil)
        #expect(model.state.outcome.value == Setup.now)
    }

    @Test
    func showsFailureWhenDatabaseIsClosed() async throws {
        let setup = try Setup()
        let model = HomeModel(parts: setup.parts)
        try setup.database.writer.close()

        await model.load()

        #expect(!model.output.isLoaded)
        #expect(model.state.failureMessage != nil)
        #expect(model.state.outcome.value == nil)
    }
}

private extension HomeModelTests {
    struct Setup {
        static let now = Date(timeIntervalSince1970: 1_791_000_000)

        let database: AppDatabase
        let parts: ScreenParts

        init() throws {
            let database = try AppDatabase.inMemory()

            self.database = database
            self.parts = ScreenParts(database: database, clock: .fixed(Self.now))
        }
    }
}
