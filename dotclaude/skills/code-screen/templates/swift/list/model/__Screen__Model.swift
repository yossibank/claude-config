import Core
import Observation
import Store

@MainActor
@Observable
public final class __Screen__Model: ScreenPerforming {
    public let state: State
    public let input: Input
    public let output: Output

    let dependencies: Dependencies

    public init(parts: ScreenParts) {
        let input = Input()

        self.state = State(wait: parts.wait)
        self.input = input
        self.output = Output(input: input)
        self.dependencies = Dependencies(database: parts.database)
    }
}

public extension __Screen__Model {
    @MainActor
    @Observable
    final class State {
        public var presented = Presented()

        public internal(set) var outcome = ScreenOutcome<__Item__>()

        public let notices: Notices

        init(wait: ScreenWait) {
            self.notices = Notices(wait: wait)
        }
    }

    struct Presented: ScreenEditable {
        public var editing = Shown<__Item__.ID>()
    }

    @MainActor
    struct Notices {
        public let error: ErrorNotice

        init(wait: ScreenWait) {
            self.error = ErrorNotice(wait: wait)
        }
    }

    @MainActor
    @Observable
    final class Input {
        public internal(set) var items: Loadable<[__Item__]> = .loading
    }

    @MainActor
    final class Output {
        let input: Input

        init(input: Input) {
            self.input = input
        }
    }
}

extension __Screen__Model {
    struct Dependencies {
        let database: AppDatabase
    }
}

public extension __Screen__Model {
    func run() async {
        await load()
        await observe()
    }

    func load() async {
        do {
            input.items = .loaded(try await dependencies.database.__item__List())
        } catch {
            input.items = .failed
            state.notices.error.show(Self.loadFailedMessage)
        }
    }

    func remove(_ item: __Item__) async {
        do {
            try await dependencies.database.delete__Item__(item.id)
            state.outcome.send(item)
        } catch {
            state.notices.error.show(Self.removeFailedMessage)
        }
    }
}

private extension __Screen__Model {
    static let loadFailedMessage = "読み込めませんでした"
    static let removeFailedMessage = "消せませんでした"

    func observe() async {
        do {
            for try await items in dependencies.database.__item__ListUpdates() {
                input.items = .loaded(items)
            }
        } catch is CancellationError {
            return
        } catch {
            state.notices.error.show(Self.loadFailedMessage)
        }
    }
}

public extension __Screen__Model.Output {
    var items: [__Item__] {
        input.items.value ?? []
    }

    var isLoaded: Bool {
        input.items.isLoaded
    }

    var statusMessage: String? {
        input.items.isFailed ? __Screen__Model.loadFailedMessage : nil
    }
}
