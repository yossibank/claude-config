import Core
import Foundation
import __Models__
import Store
import Testing

@MainActor
struct __Screen__ModelTests {
    @Test
    func refusesToSaveWithoutName() async throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)

        await model.save()
        let stored = try await setup.database.__item__List()

        #expect(!model.output.canSave)
        #expect(model.state.outcome.value == nil)
        #expect(stored.isEmpty)
    }

    @Test
    func savesAndSendsOutcome() async throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)
        model.state.fields.name = "見本"

        await model.perform {
            await $0.save()
        }.value

        let stored = try await setup.database.__item__List()

        #expect(model.state.outcome.value?.name == "見本")
        #expect(stored.map(\.name) == ["見本"])
        #expect(model.state.failureMessage == nil)
    }

    @Test
    func savesOnceWhenSavedTwice() async throws {
        let setup = try Setup()
        let model = __Screen__Model(parts: setup.parts)
        model.state.fields.name = "見本"

        await model.save()
        await model.save()
        let stored = try await setup.database.__item__List()

        #expect(stored.map(\.name) == ["見本"])
        #expect(!model.output.canSave)
    }

    @Test
    func savesEditedItemInPlace() async throws {
        let setup = try Setup()
        let saved = try await setup.save("見本")
        let model = __Screen__Model(parts: setup.parts, editing: saved)
        model.state.fields.name = "直した見本"

        await model.save()
        let stored = try await setup.database.__item__List()

        #expect(model.state.outcome.value?.id == saved.id)
        #expect(stored.map(\.name) == ["直した見本"])
    }

    @Test
    func reportsChangeAgainstOpenedDraft() async throws {
        let setup = try Setup()
        let saved = try await setup.save("見本")
        let model = __Screen__Model(parts: setup.parts, editing: saved)

        let opened = model.output.isChanged
        model.state.fields.name = "直した見本"
        let typed = model.output.isChanged
        model.state.fields.name = "見本"

        #expect(!opened)
        #expect(typed)
        #expect(!model.output.isChanged)
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

        func save(_ name: String) async throws -> __Item__ {
            try await database.save__Item__(
                __Item__Draft(name: name),
                editing: nil,
                at: Self.now
            )
        }
    }
}
