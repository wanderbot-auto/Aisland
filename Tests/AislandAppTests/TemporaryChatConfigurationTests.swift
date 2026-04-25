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
}
