import Core
import Observation
import Store

@MainActor
@Observable
public final class __Screen__Model {
    public let state = State()
    public let input: Input
    public let output: Output

    let dependencies: Dependencies

    public init(parts: ScreenParts) {
        let input = Input()

        self.input = input
        self.output = Output(input: input)
        self.dependencies = Dependencies(database: parts.database)

        refresh()
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
        public internal(set) var items: [__Item__] = []
    }

    @MainActor
    final class Output {
        let input: Input

        init(input: Input) {
            self.input = input
        }
    }

    func refresh() {
        do {
            input.items = try dependencies.database.__item__List()
        } catch {
            state.failureMessage = Self.loadFailedMessage
        }
    }

    func remove(_ item: __Item__) {
        do {
            try dependencies.database.delete__Item__(item.id)
            state.outcome.send(item)
        } catch {
            state.failureMessage = Self.removeFailedMessage
        }

        refresh()
    }
}

public extension __Screen__Model.Output {
    var isEmpty: Bool {
        input.items.isEmpty
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
}
