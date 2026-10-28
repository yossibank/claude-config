import Foundation
import GRDB

public struct AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        try Self.migrator.migrate(writer)
        self.writer = writer
    }
}

public extension AppDatabase {
    enum SetupError: Error {
        case appGroupUnavailable
    }

    static func appGroup() throws -> AppDatabase {
        let path = try groupPath()
        let pool = try DatabasePool(path: path, configuration: configuration)

        return try AppDatabase(pool)
    }

    static func inMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue(configuration: configuration)
        return try AppDatabase(queue)
    }

    static func suspend() {
        NotificationCenter.default.post(
            name: Database.suspendNotification,
            object: nil
        )
    }

    static func resume() {
        NotificationCenter.default.post(
            name: Database.resumeNotification,
            object: nil
        )
    }
}

extension AppDatabase {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1", migrate: MigrationV1.migrate)

        return migrator
    }
}

private extension AppDatabase {
    static let groupIdentifier = "group.com.yossibank.__app__"
    static let fileName = "__app__.sqlite"
    static let busyTimeout: TimeInterval = 5

    static var groupContainer: URL? {
        let manager = FileManager.default

        return manager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    static var configuration: Configuration {
        var configuration = Configuration()

        configuration.observesSuspensionNotifications = true
        configuration.busyMode = .timeout(busyTimeout)

        return configuration
    }

    static func groupPath() throws -> String {
        guard let directory = groupContainer else {
            throw SetupError.appGroupUnavailable
        }

        let url = directory.appending(path: fileName)

        return url.path(percentEncoded: false)
    }
}
