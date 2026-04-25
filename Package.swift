// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Aisland",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AislandCore",
            targets: ["AislandCore"]
        ),
        .executable(
            name: "AislandHooks",
            targets: ["AislandHooks"]
        ),
        .executable(
            name: "AislandSetup",
            targets: ["AislandSetup"]
        ),
        .executable(
            name: "AislandApp",
            targets: ["AislandApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "AislandCore"
        ),
        .executableTarget(
            name: "AislandHooks",
            dependencies: ["AislandCore"]
        ),
        .executableTarget(
            name: "AislandSetup",
            dependencies: ["AislandCore"]
        ),
        .executableTarget(
            name: "AislandApp",
            dependencies: [
                "AislandCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "AislandCoreTests",
            dependencies: ["AislandCore"]
        ),
        .testTarget(
            name: "AislandAppTests",
            dependencies: ["AislandApp", "AislandCore"]
        ),
    ]
)
