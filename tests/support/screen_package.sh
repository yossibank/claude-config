screen_package() {
    local package=$1/ios/Packages/DemoApp calls=$2
    mkdir -p "$package/Sources/Core" "$package/Sources/Store"
    screen_package_manifest >"$package/Package.swift"
    screen_package_core >"$package/Sources/Core/Stamp.swift"
    "screen_package_store_$calls" >"$package/Sources/Store/AppDatabase.swift"
}

screen_package_manifest() {
    cat <<'EOF'
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DemoApp",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    targets: [
        .target(name: "Core"),
        .target(
            name: "Store",
            dependencies: ["Core"]
        ),
        .target(
            name: "FeatureModels",
            dependencies: ["Core", "Store"]
        ),
        .target(
            name: "Features",
            dependencies: ["Core", "FeatureModels"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Core", "FeatureModels", "Features", "Store"]
        )
    ]
)
EOF
}

screen_package_core() {
    cat <<'EOF'
import Foundation

public struct Stamp: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String

    public init(
        id: UUID,
        name: String
    ) {
        self.id = id
        self.name = name
    }
}

public struct StampDraft: Equatable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public extension StampDraft {
    var problems: [String] {
        name.isEmpty ? ["名前が無い"] : []
    }
}
EOF
}

screen_package_store_async() {
    cat <<'EOF'
import Core
import Foundation

public struct AppDatabase: Sendable {
    private let storage = Storage()
}

public extension AppDatabase {
    typealias Updates = AsyncThrowingStream<[Stamp], Error>

    static func inMemory() throws -> AppDatabase {
        AppDatabase()
    }

    func stampList() async throws -> [Stamp] {
        await storage.items
    }

    func stampListUpdates() -> Updates {
        let (stream, continuation) = Updates.makeStream()
        let storage = storage

        let task = Task {
            await storage.watch(continuation)
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }

    @discardableResult
    func saveStamp(
        _ draft: StampDraft,
        editing id: Stamp.ID?,
        at _: Date
    ) async throws -> Stamp {
        await storage.save(Stamp(id: id ?? UUID(), name: draft.name))
    }

    func deleteStamp(_ id: Stamp.ID) async throws {
        await storage.delete(id)
    }
}

actor Storage {
    private(set) var items: [Stamp] = []

    private var watchers: [AppDatabase.Updates.Continuation] = []
}

extension Storage {
    func watch(_ watcher: AppDatabase.Updates.Continuation) {
        watcher.yield(items)
        watchers.append(watcher)
    }

    func save(_ item: Stamp) -> Stamp {
        items.removeAll { $0.id == item.id }
        items.append(item)
        publish()

        return item
    }

    func delete(_ id: Stamp.ID) {
        items.removeAll { $0.id == id }
        publish()
    }

    private func publish() {
        for watcher in watchers {
            watcher.yield(items)
        }
    }
}
EOF
}

screen_package_store_sync() {
    cat <<'EOF'
import Core
import Foundation
import Synchronization

public final class AppDatabase: Sendable {
    private let items = Mutex<[Stamp]>([])
}

public extension AppDatabase {
    static func inMemory() throws -> AppDatabase {
        AppDatabase()
    }

    func stampList() throws -> [Stamp] {
        items.withLock { $0 }
    }

    @discardableResult
    func saveStamp(
        _ draft: StampDraft,
        editing id: Stamp.ID?,
        at _: Date
    ) throws -> Stamp {
        let item = Stamp(id: id ?? UUID(), name: draft.name)

        items.withLock { items in
            items.removeAll { $0.id == item.id }
            items.append(item)
        }

        return item
    }

    func deleteStamp(_ id: Stamp.ID) throws {
        items.withLock { items in
            items.removeAll { $0.id == id }
        }
    }
}
EOF
}
