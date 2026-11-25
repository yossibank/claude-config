@testable import AppFeature
import FeatureModels
import Foundation
import Store
import Testing

@MainActor
struct AppModelTests {
    @Test
    func startsOpening() {
        let opener = Opener()
        let model = AppModel {
            try await opener.open()
        }

        #expect(model.state.launch.name == "opening")
    }

    @Test
    func opensHomeWhenDatabaseOpens() async {
        let opener = Opener()
        let model = AppModel {
            try await opener.open()
        }

        await model.open()

        #expect(model.state.launch.name == "ready")
    }

    @Test
    func failsWhenDatabaseDoesNotOpen() async {
        let opener = Opener(failures: 1)
        let model = AppModel {
            try await opener.open()
        }

        await model.open()

        #expect(model.state.launch.name == "failed")
    }

    @Test
    func retriesAfterFailure() async {
        let opener = Opener(failures: 1)
        let model = AppModel {
            try await opener.open()
        }

        await model.open()

        await model.perform {
            await $0.retryOpen()
        }.value

        #expect(model.state.launch.name == "ready")
    }
}

extension AppModelTests {
    actor Opener {
        private var failures: Int

        init(failures: Int = 0) {
            self.failures = failures
        }

        func open() throws -> ScreenParts {
            guard failures == 0 else {
                failures -= 1
                throw AppDatabase.SetupError.appGroupUnavailable
            }

            let database = try AppDatabase.inMemory()
            let now = Date(timeIntervalSince1970: 1_791_000_000)

            return ScreenParts(database: database, clock: .fixed(now))
        }
    }
}

private extension AppModel.Launch {
    var name: String {
        switch self {
        case .opening: "opening"
        case .ready: "ready"
        case .failed: "failed"
        }
    }
}
