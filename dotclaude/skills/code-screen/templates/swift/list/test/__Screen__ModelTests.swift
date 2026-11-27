import Core
import Foundation
import __Models__
import Store
import Testing

@MainActor
struct __Screen__ModelTests {
    @Test
    func showsNothingBeforeLoading() throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)

        #expect(model.output.items.isEmpty)
        #expect(!model.output.isLoaded)
    }

    @Test
    func loadsSavedItems() async throws {
        let setup = try Setup()
        try await setup.save("見本")
        let model = __Screen__Model(parts: setup.parts)

        await model.load()

        #expect(model.output.items.map(\.name) == ["見本"])
        #expect(model.output.isLoaded)
        #expect(model.state.notices.error.message == nil)
    }

    @Test
    func followsChanges() async throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)

        let task = Task {
            await model.run()
        }

        try await setup.save("見本")

        try await setup.wait {
            model.output.items.count == 1
        }

        task.cancel()

        #expect(model.output.items.map(\.name) == ["見本"])
    }

    @Test
    func removesAndSendsOutcome() async throws {
        let setup = try Setup()
        let saved = try await setup.save("見本")
        let model = __Screen__Model(parts: setup.parts)
        await model.load()

        await model.perform {
            await $0.remove(saved)
        }.value

        await model.load()

        #expect(model.state.outcome.value?.id == saved.id)
        #expect(model.output.items.isEmpty)
    }
}

private extension __Screen__ModelTests {
    struct Setup {
        static let now = Date(timeIntervalSince1970: 1_791_000_000)

        let database: AppDatabase
        let parts: ScreenParts

        init() throws {
            let database = try AppDatabase.inMemory()

            self.database = database
            self.parts = ScreenParts(database: database, clock: .fixed(Self.now))
        }

        @discardableResult
        func save(_ name: String) async throws -> __Item__ {
            try await database.save__Item__(
                __Item__Draft(name: name),
                editing: nil,
                at: Self.now
            )
        }

        @MainActor
        func wait(until isReady: @MainActor () -> Bool) async throws {
            for _ in 0..<500 where !isReady() {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
    }
}
