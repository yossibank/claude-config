import Core
import Observation
import Store

@MainActor
@Observable
public final class __Screen__Model {
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
        public var name: String
        public var failureMessage: String?
        public var isConfirmingDiscard = false

        public internal(set) var outcome = ScreenOutcome<__Item__>()

        init(name: String) {
            self.name = name
        }
    }

    @MainActor
    @Observable
    final class Input {
        public internal(set) var editing: __Item__?

        var baseline: __Item__Draft

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

    func save() {
        guard output.canSave else {
            return
        }

        let draft = output.draft

        do {
            let saved = try dependencies.database.save__Item__(
                draft,
                editing: input.editing?.id,
                at: dependencies.clock.now
            )

            input.editing = saved
            input.baseline = draft
            state.outcome.send(saved)
        } catch {
            state.failureMessage = Self.saveFailedMessage
        }
    }
}

public extension __Screen__Model.Output {
    var draft: __Item__Draft {
        __Item__Draft(name: state.name)
    }

    var canSave: Bool {
        draft.problems.isEmpty && isChanged
    }

    var isChanged: Bool {
        draft != input.baseline
    }
}

extension __Screen__Model {
    struct Dependencies {
        let database: AppDatabase
        let clock: ScreenClock
    }
}

private extension __Screen__Model {
    static let saveFailedMessage = "保存できませんでした"
}
