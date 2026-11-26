import FeatureModels
import Observation

@MainActor
@Observable
final class AppModel: ScreenPerforming {
    let state = State()
    let dependencies: Dependencies

    init(open: @escaping @Sendable () async throws -> ScreenParts) {
        self.dependencies = Dependencies(open: open)
    }
}

extension AppModel {
    enum Launch {
        case opening
        case ready(HomeModel)
        case failed
    }

    @MainActor
    @Observable
    final class State {
        fileprivate(set) var launch: Launch = .opening
    }

    struct Dependencies {
        let open: @Sendable () async throws -> ScreenParts
    }
}

extension AppModel {
    func open() async {
        guard case .opening = state.launch else {
            return
        }

        do {
            let parts = try await dependencies.open()
            state.launch = .ready(HomeModel(parts: parts))
        } catch {
            state.launch = .failed
        }
    }

    func retryOpen() async {
        guard case .failed = state.launch else {
            return
        }

        state.launch = .opening
        await open()
    }
}
