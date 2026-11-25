import Core
import Observation
import Store

@MainActor
@Observable
public final class __Screen__Model: ScreenPerforming {
    public let state = State()
    public let input: Input
    public let output: Output

    let dependencies: Dependencies

    public init(parts: ScreenParts) {
        let input = Input()

        self.input = input
        self.output = Output(input: input)
        self.dependencies = Dependencies(database: parts.database)
    }
}

public extension __Screen__Model {
    @MainActor
    @Observable
    final class State {
        public var failureMessage: String?
        public var editing: __Item__?

        public internal(set) var outcome = ScreenOutcome<__Item__>()
    }

    @MainActor
    @Observable
    final class Input {
        public internal(set) var items: [__Item__]?
    }

    @MainActor
    final class Output {
        let input: Input

        init(input: Input) {
            self.input = input
        }
    }

    func run() async {
        await load()
        await observe()
    }

    func load() async {
        do {
            input.items = try await dependencies.database.__item__List()
        } catch {
            state.failureMessage = Self.loadFailedMessage
        }
    }

    func remove(_ item: __Item__) async {
        do {
            try await dependencies.database.delete__Item__(item.id)
            state.outcome.send(item)
        } catch {
            state.failureMessage = Self.removeFailedMessage
        }
    }
}

public extension __Screen__Model.Output {
    var items: [__Item__] {
        input.items ?? []
    }

    var isLoaded: Bool {
        input.items != nil
    }
}

extension __Screen__Model {
    struct Dependencies {
        let database: AppDatabase
    }
}

private extension __Screen__Model {
    static let loadFailedMessage = "読み込めませんでした"
    static let removeFailedMessage = "消せませんでした"

    func observe() async {
        do {
            for try await items in dependencies.database.__item__ListUpdates() {
                input.items = items
            }
        } catch is CancellationError {
            return
        } catch {
            state.failureMessage = Self.loadFailedMessage
        }
    }
}
