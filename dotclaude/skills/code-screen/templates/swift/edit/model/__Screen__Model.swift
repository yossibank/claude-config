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

    public init(
        parts: ScreenParts,
        editing item: __Item__? = nil
    ) {
        let name = item?.name ?? ""
        let state = State(name: name)
        let input = Input(editing: item, baseline: __Item__Draft(name: name))

        self.state = state
        self.input = input
        self.output = Output(input: input, state: state)
        self.dependencies = Dependencies(database: parts.database, clock: parts.clock)
    }
}

public extension __Screen__Model {
    @MainActor
    @Observable
    final class State {
        public var fields: Fields
        public var prompt = Shown<Prompt>()

        public internal(set) var failureMessage: String?
        public internal(set) var outcome = ScreenOutcome<__Item__>()

        public let saving = ModelTask()

        init(name: String) {
            self.fields = Fields(name: name)
        }
    }

    struct Fields: ScreenEditable {
        public var name: String
    }

    enum Prompt: Hashable, Sendable {
        case discard
    }

    @MainActor
    @Observable
    final class Input {
        public let editing: __Item__?

        let baseline: __Item__Draft

        init(
            editing: __Item__?,
            baseline: __Item__Draft
        ) {
            self.editing = editing
            self.baseline = baseline
        }
    }

    @MainActor
    final class Output {
        let input: Input
        let state: State

        init(
            input: Input,
            state: State
        ) {
            self.input = input
            self.state = state
        }
    }
}

extension __Screen__Model {
    struct Dependencies {
        let database: AppDatabase
        let clock: ScreenClock
    }
}

public extension __Screen__Model {
    func save() async {
        guard output.canSave else {
            return
        }

        do {
            let saved = try await state.saving.attempt {
                try await dependencies.database.save__Item__(
                    output.draft,
                    editing: input.editing?.id,
                    at: dependencies.clock.now
                )
            }

            state.outcome.send(saved)
        } catch {
            state.failureMessage = Self.saveFailedMessage
        }
    }
}

private extension __Screen__Model {
    static let saveFailedMessage = "保存できませんでした"
}

public extension __Screen__Model.Output {
    var draft: __Item__Draft {
        __Item__Draft(name: state.fields.name)
    }

    var canSave: Bool {
        draft.problems.isEmpty && !state.saving.isRunning && state.outcome.value == nil
    }

    var isChanged: Bool {
        draft != input.baseline
    }
}
