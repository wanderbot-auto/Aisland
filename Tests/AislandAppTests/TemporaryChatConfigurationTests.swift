import Foundation
import Testing
@testable import AislandApp

struct TemporaryChatConfigurationTests {
    @Test
    func temporaryChatSurfaceIsNotNotificationCard() {
        let surface = IslandSurface.temporaryChat

        #expect(surface.sessionID == nil)
        #expect(!surface.isNotificationCard)
        #expect(surface.matchesCurrentState(of: nil))
    }

    @Test
    func providerSearchTokensIncludeProviderAndModelNames() {
        #expect(LLMProviderKind.openRouter.searchTokens.contains(where: { $0.contains("openrouter") }))
        #expect(LLMProviderKind.anthropic.searchTokens.contains(where: { $0.contains("claude") }))
        #expect(LLMProviderKind.googleGemini.searchTokens.contains(where: { $0.contains("gemini") }))
    }

    @Test
    func chatConfigurationFallsBackToProviderDefaults() {
        let configuration = LLMChatConfiguration(
            provider: .anthropic,
            model: "  ",
            baseURL: "  ",
            apiKey: "key"
        )

        #expect(configuration.effectiveModel == LLMProviderKind.anthropic.defaultModel)
        #expect(configuration.effectiveBaseURL?.absoluteString == LLMProviderKind.anthropic.defaultBaseURL)
    }

    @Test
    func capabilityRegistryGatesProviderModelFeatures() {
        #expect(TemporaryChatCapabilityRegistry.capabilities(provider: .openAI, model: "gpt-4o-mini").contains(.webSearch))
        #expect(TemporaryChatCapabilityRegistry.capabilities(provider: .openAI, model: "gpt-4o-mini").contains(.imageInput))
        #expect(TemporaryChatCapabilityRegistry.capabilities(provider: .perplexity, model: "sonar-pro") == [.webSearch])
        #expect(TemporaryChatCapabilityRegistry.capabilities(provider: .deepSeek, model: "deepseek-chat").isEmpty)
    }

    @Test
    func temporaryChatConfigurationPersistsOutsideKeychain() throws {
        let databaseURL = temporaryDatabaseURL()
        let store = TemporaryChatConfigurationStore(databaseURL: databaseURL)
        let configuration = TemporaryChatStoredConfiguration(
            provider: .openRouter,
            model: "anthropic/claude-3.5-sonnet",
            baseURL: "https://openrouter.ai/api/v1"
        )

        try store.saveConfiguration(configuration)

        #expect(try store.loadConfiguration() == configuration)
        let databaseBytes = try Data(contentsOf: databaseURL)
        let databaseText = String(decoding: databaseBytes, as: UTF8.self)
        #expect(databaseText.contains("anthropic/claude-3.5-sonnet"))
        #expect(!databaseText.contains("sk-secret-test-key"))
    }

    @Test
    func tokenEstimatorTracksInputAndContextRatio() {
        let messages = [
            TemporaryChatMessage(role: .user, content: "hello world"),
            TemporaryChatMessage(role: .assistant, parts: [
                .text(TemporaryChatTextPart(text: "你好")),
                .webCitation(TemporaryChatWebCitationPart(title: "Example", url: "https://example.com")),
            ]),
        ]

        let stats = TemporaryChatTokenStats.estimate(
            messages: messages,
            provider: .anthropic,
            model: "claude-3-5-sonnet-latest"
        )

        #expect(stats.inputTokens > 0)
        #expect(stats.contextWindow == 200_000)
        #expect(stats.contextRatio > 0)
        #expect(stats.source == .estimated)
    }

    @Test
    func temporaryChatMessageKeepsTextCompatibilityOverParts() {
        let attachment = TemporaryChatAttachmentPart(
            filename: "error.png",
            mediaType: "image/png",
            data: Data([0, 1, 2])
        )
        let message = TemporaryChatMessage(role: .user, parts: [
            .text(TemporaryChatTextPart(text: "Explain this")),
            .image(attachment),
        ])

        #expect(message.content == "Explain this")
        #expect(message.requiredCapabilities == [.imageInput])
        #expect(message.isRenderable)
    }

    @MainActor
    @Test
    func temporaryChatStreamsAssistantReplyInPlace() async throws {
        let model = makeAppModel(temporaryChatStream: { messages, _ in
            #expect(messages.map(\.role) == [.user])
            #expect(messages.map(\.content) == ["Show markdown and an image"])

            return AsyncThrowingStream { continuation in
                continuation.yield(.text("**Done**"))
                continuation.yield(.text("\n\n![cat](https://example.com/cat.png)"))
                continuation.finish()
            }
        })

        model.sendTemporaryChatMessage("Show markdown and an image")
        try await waitUntil {
            !model.temporaryChatIsSending
        }

        #expect(model.temporaryChatLastError == nil)
        #expect(model.temporaryChatMessages.map(\.role) == [.user, .assistant])
        #expect(model.temporaryChatMessages.last?.content == "**Done**\n\n![cat](https://example.com/cat.png)")
        #expect(model.temporaryChatTokenStats.inputTokens > 0)
    }

    @MainActor
    @Test
    func temporaryChatUsesProviderReportedInputTokens() async throws {
        let model = makeAppModel(temporaryChatStream: { _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.text("Done"))
                continuation.yield(.usage(TemporaryChatUsage(inputTokens: 42, outputTokens: 7, totalTokens: 49)))
                continuation.finish()
            }
        })

        model.sendTemporaryChatMessage("Ping")
        try await waitUntil {
            !model.temporaryChatIsSending
        }

        #expect(model.temporaryChatTokenStats.inputTokens == 42)
        #expect(model.temporaryChatTokenStats.source == .provider)
    }

    @MainActor
    @Test
    func temporaryChatSendsPendingPartsAndWebCapability() async throws {
        let image = TemporaryChatAttachmentPart(
            filename: "screen.png",
            mediaType: "image/png",
            data: Data([0, 1, 2, 3])
        )
        let model = makeAppModel(temporaryChatStream: { messages, configuration in
            #expect(configuration.enabledCapabilities == [.webSearch])
            #expect(messages.first?.parts.count == 2)
            #expect(messages.first?.requiredCapabilities == [.imageInput])

            return AsyncThrowingStream { continuation in
                continuation.yield(.text("Done"))
                continuation.finish()
            }
        })
        model.temporaryChatPendingParts = [.image(image)]
        model.temporaryChatWebSearchEnabled = true

        model.sendTemporaryChatMessage("Explain this")
        try await waitUntil {
            !model.temporaryChatIsSending
        }

        #expect(model.temporaryChatPendingParts.isEmpty)
        #expect(!model.temporaryChatWebSearchEnabled)
        #expect(model.temporaryChatLastError == nil)
    }

    @MainActor
    @Test
    func temporaryChatAppendsStreamedSourcesToAssistantMessage() async throws {
        let model = makeAppModel(temporaryChatStream: { _, _ in
            AsyncThrowingStream { continuation in
                continuation.yield(.text("Found it"))
                continuation.yield(.source(TemporaryChatWebCitationPart(title: "Docs", url: "https://example.com/docs")))
                continuation.finish()
            }
        })

        model.sendTemporaryChatMessage("Find docs")
        try await waitUntil {
            !model.temporaryChatIsSending
        }

        guard let assistant = model.temporaryChatMessages.last else {
            Issue.record("Missing assistant message")
            return
        }
        #expect(assistant.content == "Found it")
        #expect(assistant.parts.contains { part in
            if case let .webCitation(citation) = part {
                return citation.title == "Docs" && citation.url == "https://example.com/docs"
            }
            return false
        })
    }

    @MainActor
    @Test
    func temporaryChatRemovesEmptyStreamingPlaceholderOnError() async throws {
        let model = makeAppModel(temporaryChatStream: { _, _ in
            AsyncThrowingStream { continuation in
                continuation.finish(throwing: TemporaryChatError.emptyResponse)
            }
        })

        model.sendTemporaryChatMessage("Ping")
        try await waitUntil {
            !model.temporaryChatIsSending
        }

        #expect(model.temporaryChatMessages.map(\.role) == [.user])
        #expect(model.temporaryChatLastError == TemporaryChatError.emptyResponse.localizedDescription)
    }

    @MainActor
    @Test
    func temporaryChatLoadsAndSavesProviderScopedAPIKeys() {
        let recorder = APIKeyRecorder(values: [
            .openAI: "openai-key",
            .anthropic: "anthropic-key",
        ])
        let model = makeAppModel(
            temporaryChatAPIKeyLoader: { recorder.load($0) },
            temporaryChatAPIKeySaver: { recorder.save($0, for: $1) }
        )

        #expect(model.temporaryChatAPIKey == "openai-key")
        model.temporaryChatProvider = .anthropic
        #expect(model.temporaryChatAPIKey == "anthropic-key")

        model.temporaryChatAPIKey = "new-anthropic-key"
        #expect(recorder.saved == [.init(provider: .anthropic, value: "new-anthropic-key")])
    }
}

@MainActor
private func makeAppModel(
    temporaryChatStream: @escaping TemporaryChatStreamFactory = { _, _ in
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    },
    temporaryChatAPIKeyLoader: @escaping @Sendable (LLMProviderKind) -> String = { _ in "" },
    temporaryChatAPIKeySaver: @escaping @Sendable (String, LLMProviderKind) -> Void = { _, _ in }
) -> AppModel {
    AppModel(
        temporaryChatStream: temporaryChatStream,
        temporaryChatConfigurationStore: TemporaryChatConfigurationStore(databaseURL: temporaryDatabaseURL()),
        temporaryChatAPIKeyLoader: temporaryChatAPIKeyLoader,
        temporaryChatAPIKeySaver: temporaryChatAPIKeySaver
    )
}

private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("aisland-chat-\(UUID().uuidString)")
        .appendingPathComponent("app.sqlite")
}

private struct SavedAPIKey: Equatable {
    var provider: LLMProviderKind
    var value: String
}

private final class APIKeyRecorder: @unchecked Sendable {
    private var values: [LLMProviderKind: String]
    private(set) var saved: [SavedAPIKey] = []

    init(values: [LLMProviderKind: String]) {
        self.values = values
    }

    func load(_ provider: LLMProviderKind) -> String {
        values[provider] ?? ""
    }

    func save(_ value: String, for provider: LLMProviderKind) {
        values[provider] = value
        saved.append(SavedAPIKey(provider: provider, value: value))
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout

    while !condition() {
        if clock.now >= deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        await Task.yield()
        try await Task.sleep(for: .milliseconds(10))
    }
}
