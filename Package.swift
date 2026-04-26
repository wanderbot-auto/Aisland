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
        .package(url: "https://github.com/teunlao/swift-ai-sdk.git", from: "0.17.6"),
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
                .product(name: "SwiftAISDK", package: "swift-ai-sdk"),
                .product(name: "AISDKProviderUtils", package: "swift-ai-sdk"),
                .product(name: "OpenAIProvider", package: "swift-ai-sdk"),
                .product(name: "OpenAICompatibleProvider", package: "swift-ai-sdk"),
                .product(name: "AnthropicProvider", package: "swift-ai-sdk"),
                .product(name: "GoogleProvider", package: "swift-ai-sdk"),
                .product(name: "GroqProvider", package: "swift-ai-sdk"),
                .product(name: "MistralProvider", package: "swift-ai-sdk"),
                .product(name: "PerplexityProvider", package: "swift-ai-sdk"),
                .product(name: "DeepSeekProvider", package: "swift-ai-sdk"),
                .product(name: "XAIProvider", package: "swift-ai-sdk"),
                .product(name: "TogetherAIProvider", package: "swift-ai-sdk"),
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
            dependencies: [
                "AislandApp",
                "AislandCore",
                .product(name: "AISDKProviderUtils", package: "swift-ai-sdk"),
            ]
        ),
    ]
)
