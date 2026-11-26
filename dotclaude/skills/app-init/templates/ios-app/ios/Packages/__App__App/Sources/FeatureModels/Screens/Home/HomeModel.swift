import Foundation
import Observation
import Store

@MainActor
@Observable
public final class HomeModel: ScreenPerforming {
    public let state = State()
    public let input: Input
    public let output: Output

    let dependencies: Dependencies

    public init(parts: ScreenParts) {
        let input = Input()

        self.input = input
        self.output = Output(input: input)
        self.dependencies = Dependencies(database: parts.database, clock: parts.clock)
    }
}

public extension HomeModel {
    @MainActor
    @Observable
    final class State {
        public var failureMessage: String?

        public internal(set) var outcome = ScreenOutcome<Date>()
    }

    @MainActor
    @Observable
    final class Input {
        public internal(set) var migrations: [String]?
    }

    @MainActor
    final class Output {
        let input: Input

        init(input: Input) {
            self.input = input
        }
    }
}

extension HomeModel {
    struct Dependencies {
        let database: AppDatabase
        let clock: ScreenClock
    }
}

public extension HomeModel {
    func load() async {
        do {
            input.migrations = try await dependencies.database.appliedMigrations()
            state.failureMessage = nil
            state.outcome.send(dependencies.clock.now)
        } catch {
            state.failureMessage = Self.loadFailedMessage
        }
    }
}

private extension HomeModel {
    static let loadFailedMessage = "読み込めませんでした"
}

public extension HomeModel.Output {
    var isLoaded: Bool {
        input.migrations != nil
    }

    var schemaVersion: Int {
        input.migrations?.count ?? 0
    }
}
