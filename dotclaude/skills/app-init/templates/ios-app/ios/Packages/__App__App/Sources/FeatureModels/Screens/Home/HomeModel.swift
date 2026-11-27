import Foundation
import Observation
import Store

@MainActor
@Observable
public final class HomeModel: ScreenPerforming {
    public let state: State
    public let input: Input
    public let output: Output

    let dependencies: Dependencies

    public init(parts: ScreenParts) {
        let input = Input()

        self.state = State(wait: parts.wait)
        self.input = input
        self.output = Output(input: input)
        self.dependencies = Dependencies(database: parts.database, clock: parts.clock)
    }
}

public extension HomeModel {
    @MainActor
    @Observable
    final class State {
        public internal(set) var outcome = ScreenOutcome<Date>()

        public let notices: Notices

        init(wait: ScreenWait) {
            self.notices = Notices(wait: wait)
        }
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
        public internal(set) var migrations: Loadable<[String]> = .loading
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
            input.migrations = .loaded(try await dependencies.database.appliedMigrations())
            state.notices.error.clear()
            state.outcome.send(dependencies.clock.now)
        } catch {
            input.migrations = .failed
            state.notices.error.show(Self.loadFailedMessage)
        }
    }
}

private extension HomeModel {
    static let loadFailedMessage = "読み込めませんでした"
}

public extension HomeModel.Output {
    var isLoaded: Bool {
        input.migrations.isLoaded
    }

    var isFailed: Bool {
        input.migrations.isFailed
    }

    var schemaVersion: Int {
        input.migrations.value?.count ?? 0
    }
}
