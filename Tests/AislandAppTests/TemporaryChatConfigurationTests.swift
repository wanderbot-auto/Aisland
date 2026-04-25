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

    @MainActor
    @Test
    func temporaryChatStreamsAssistantReplyInPlace() async throws {
        let model = AppModel(temporaryChatStream: { messages, _ in
            #expect(messages.map(\.role) == [.user])
            #expect(messages.map(\.content) == ["Show markdown and an image"])

            return AsyncThrowingStream { continuation in
                continuation.yield("**Done**")
                continuation.yield("\\n\\n![cat](https://example.com/cat.png)")
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
    }

    @MainActor
    @Test
    func temporaryChatRemovesEmptyStreamingPlaceholderOnError() async throws {
        let model = AppModel(temporaryChatStream: { _, _ in
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
