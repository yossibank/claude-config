import Core
import Foundation
import __Models__
import Store
import Testing

@MainActor
struct __Screen__ModelTests {
    @Test
    func startsEmptyWithoutSavedItems() throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)

        #expect(model.input.items.isEmpty)
        #expect(model.output.isEmpty)
        #expect(model.state.failureMessage == nil)
    }

    @Test
    func startsWithSavedItems() throws {
        let setup = try Setup()
        try setup.save("見本")
        let model = __Screen__Model(parts: setup.parts)

        #expect(model.input.items.map(\.name) == ["見本"])
        #expect(!model.output.isEmpty)
    }

    @Test
    func showsChangesOnlyAfterRefresh() throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)

        try setup.save("見本")
        let before = model.input.items
        model.refresh()

        #expect(before.isEmpty)
        #expect(model.input.items.map(\.name) == ["見本"])
    }

    @Test
    func refreshesWithoutWriting() throws {
        let setup = try Setup()
        try setup.save("見本")
        let model = __Screen__Model(parts: setup.parts)

        model.refresh()
        model.refresh()
        let stored = try setup.database.__item__List()

        #expect(stored.map(\.name) == ["見本"])
        #expect(model.state.outcome.value == nil)
    }

    @Test
    func removesAndSendsOutcome() throws {
        let setup = try Setup()
        let saved = try setup.save("見本")
        let model = __Screen__Model(parts: setup.parts)

        model.remove(saved)
        let stored = try setup.database.__item__List()

        #expect(model.state.outcome.value?.id == saved.id)
        #expect(model.input.items.isEmpty)
        #expect(stored.isEmpty)
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
        func save(_ name: String) throws -> __Item__ {
            try database.save__Item__(
                __Item__Draft(name: name),
                editing: nil,
                at: Self.now
            )
        }
    }
}
