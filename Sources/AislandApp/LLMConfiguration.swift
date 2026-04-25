import Foundation

enum LLMProviderKind: String, CaseIterable, Identifiable, Codable {
    case openAI
    case anthropic
    case googleGemini
    case openRouter
    case customOpenAICompatible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic Claude"
        case .googleGemini: "Google Gemini"
        case .openRouter: "OpenRouter"
        case .customOpenAICompatible: "Custom OpenAI-compatible"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-3-5-sonnet-latest"
        case .googleGemini: "gemini-1.5-pro"
        case .openRouter: "openai/gpt-4o-mini"
        case .customOpenAICompatible: ""
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com"
        case .anthropic: "https://api.anthropic.com"
        case .googleGemini: "https://generativelanguage.googleapis.com"
        case .openRouter: "https://openrouter.ai/api"
        case .customOpenAICompatible: "http://localhost:11434"
        }
    }

    var usesOpenAICompatibleChatCompletions: Bool {
        switch self {
        case .openAI, .openRouter, .customOpenAICompatible:
            true
        case .anthropic, .googleGemini:
            false
        }
    }
}

struct LLMChatConfiguration: Equatable, Sendable {
    var provider: LLMProviderKind
    var model: String
    var baseURL: String
    var apiKey: String

    var effectiveModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    var effectiveBaseURL: URL? {
        let raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: raw.isEmpty ? provider.defaultBaseURL : raw)
    }
}
