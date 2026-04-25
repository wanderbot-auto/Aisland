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
    func openRouterUsesOpenAICompatibleTransport() {
        #expect(LLMProviderKind.openRouter.usesOpenAICompatibleChatCompletions)
        #expect(LLMProviderKind.openAI.usesOpenAICompatibleChatCompletions)
        #expect(!LLMProviderKind.anthropic.usesOpenAICompatibleChatCompletions)
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
}
