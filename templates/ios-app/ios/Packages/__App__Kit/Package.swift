// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "__App__Kit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        ),
        .library(
            name: "Store",
            targets: ["Store"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/groue/GRDB.swift",
            from: "7.11.1"
        )
    ],
    targets: [
        .target(name: "Core"),
        .target(
            name: "Store",
            dependencies: [
                "Core",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "StoreTests",
            dependencies: ["Store"]
        )
    ]
)
