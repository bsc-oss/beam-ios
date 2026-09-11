// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Compound",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Compound", targets: ["Compound"])
    ],
    dependencies: [
        // PG_CHANGED - use pg-compound-design-tokens @ 1.0.2 instead of upstream element-hq/compound-design-tokens 10.1.1
        .package(url: "git@private-registry:general/pg/ui-compounds/pg-compound-design-tokens.git", exact: "1.0.2"),
        // .package(path: "../../pg-compound/pg-compound-design-tokens"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", from: "26.0.1"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.2")
    ],
    targets: [
        .target(
            name: "Compound",
            dependencies: [
                .product(name: "CompoundDesignTokens", package: "pg-compound-design-tokens"),
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "SFSafeSymbols", package: "SFSafeSymbols")
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "CompoundTests",
            dependencies: [
                "Compound",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "__Snapshots__"
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
