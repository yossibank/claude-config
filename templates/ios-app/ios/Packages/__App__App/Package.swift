// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "__App__App",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "AppFeature",
            targets: ["AppFeature"]
        )
    ],
    dependencies: [
        .package(path: "../__App__Kit")
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                "DesignSystem",
                "Features",
                .product(name: "Core", package: "__App__Kit"),
                .product(name: "Store", package: "__App__Kit")
            ]
        ),
        .target(
            name: "Features",
            dependencies: [
                "DesignSystem",
                .product(name: "Core", package: "__App__Kit"),
                .product(name: "Store", package: "__App__Kit")
            ]
        ),
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "Core", package: "__App__Kit")
            ]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature"]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"]
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"]
        )
    ]
)
