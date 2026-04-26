import Foundation

enum LLMProviderKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case openAI
    case anthropic
    case googleGemini
    case openRouter
    case groq
    case mistral
    case perplexity
    case deepSeek
    case xAI
    case togetherAI
    case customOpenAICompatible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic Claude"
        case .googleGemini: "Google Gemini"
        case .openRouter: "OpenRouter"
        case .groq: "Groq"
        case .mistral: "Mistral AI"
        case .perplexity: "Perplexity"
        case .deepSeek: "DeepSeek"
        case .xAI: "xAI"
        case .togetherAI: "Together AI"
        case .customOpenAICompatible: "Custom OpenAI-compatible"
        }
    }

    var shortName: String {
        switch self {
        case .openAI: "OAI"
        case .anthropic: "ANT"
        case .googleGemini: "GEM"
        case .openRouter: "OR"
        case .groq: "GRQ"
        case .mistral: "MIS"
        case .perplexity: "PPLX"
        case .deepSeek: "DS"
        case .xAI: "xAI"
        case .togetherAI: "TGR"
        case .customOpenAICompatible: "API"
        }
    }

    var systemImageName: String {
        switch self {
        case .openAI: "sparkles"
        case .anthropic: "brain.head.profile"
        case .googleGemini: "diamond.fill"
        case .openRouter: "arrow.triangle.branch"
        case .groq: "bolt.fill"
        case .mistral: "wind"
        case .perplexity: "questionmark.bubble.fill"
        case .deepSeek: "scope"
        case .xAI: "xmark"
        case .togetherAI: "person.3.fill"
        case .customOpenAICompatible: "network"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-3-5-sonnet-latest"
        case .googleGemini: "gemini-1.5-pro"
        case .openRouter: "openai/gpt-4o-mini"
        case .groq: "llama-3.3-70b-versatile"
        case .mistral: "mistral-large-latest"
        case .perplexity: "sonar-pro"
        case .deepSeek: "deepseek-chat"
        case .xAI: "grok-2-latest"
        case .togetherAI: "meta-llama/Llama-3.3-70B-Instruct-Turbo"
        case .customOpenAICompatible: ""
        }
    }

    var popularModels: [String] {
        switch self {
        case .openAI:
            ["gpt-4o-mini", "gpt-4o", "gpt-4.1", "gpt-4.1-mini"]
        case .anthropic:
            ["claude-3-5-sonnet-latest", "claude-3-5-haiku-latest", "claude-3-opus-latest"]
        case .googleGemini:
            ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-2.0-flash"]
        case .openRouter:
            ["openai/gpt-4o-mini", "anthropic/claude-3.5-sonnet", "google/gemini-flash-1.5"]
        case .groq:
            ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"]
        case .mistral:
            ["mistral-large-latest", "mistral-small-latest", "codestral-latest"]
        case .perplexity:
            ["sonar-pro", "sonar", "sonar-reasoning-pro"]
        case .deepSeek:
            ["deepseek-chat", "deepseek-reasoner"]
        case .xAI:
            ["grok-2-latest", "grok-2-vision-latest"]
        case .togetherAI:
            ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "deepseek-ai/DeepSeek-V3", "Qwen/Qwen2.5-72B-Instruct-Turbo"]
        case .customOpenAICompatible:
            ["llama3.2", "qwen2.5", "local-model"]
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .googleGemini: "https://generativelanguage.googleapis.com/v1beta"
        case .openRouter: "https://openrouter.ai/api/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .mistral: "https://api.mistral.ai/v1"
        case .perplexity: "https://api.perplexity.ai"
        case .deepSeek: "https://api.deepseek.com"
        case .xAI: "https://api.x.ai/v1"
        case .togetherAI: "https://api.together.xyz/v1"
        case .customOpenAICompatible: "http://localhost:11434/v1"
        }
    }

    var sdkProviderName: String {
        switch self {
        case .customOpenAICompatible: "OpenAI-compatible"
        default: displayName
        }
    }

    var searchTokens: [String] {
        ([displayName, shortName, sdkProviderName, rawValue] + popularModels)
            .map { $0.lowercased() }
    }
}

struct LLMChatConfiguration: Equatable, Sendable {
    var provider: LLMProviderKind
    var model: String
    var baseURL: String
    var apiKey: String
    var enabledCapabilities: Set<TemporaryChatCapability>
    var webSearchMode: TemporaryChatWebSearchMode

    init(
        provider: LLMProviderKind,
        model: String,
        baseURL: String,
        apiKey: String,
        enabledCapabilities: Set<TemporaryChatCapability> = [],
        webSearchMode: TemporaryChatWebSearchMode = .auto
    ) {
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.enabledCapabilities = enabledCapabilities
        self.webSearchMode = webSearchMode
    }

    var effectiveModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    var effectiveBaseURLString: String {
        let raw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = raw.isEmpty ? provider.defaultBaseURL : raw
        return provider.normalizedBaseURL(candidate)
    }

    var effectiveBaseURL: URL? {
        URL(string: effectiveBaseURLString)
    }
}

enum TemporaryChatCapabilityRegistry {
    static func capabilities(for configuration: LLMChatConfiguration) -> Set<TemporaryChatCapability> {
        capabilities(provider: configuration.provider, model: configuration.effectiveModel)
    }

    static func capabilities(provider: LLMProviderKind, model rawModel: String) -> Set<TemporaryChatCapability> {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isVisionModel = model.contains("vision")
            || model.contains("gpt-4o")
            || model.contains("gpt-4.1")
            || model.hasPrefix("o3")
            || model.hasPrefix("o4")
            || model.contains("claude")
            || model.contains("gemini")
            || model.contains("grok")

        switch provider {
        case .openAI:
            var capabilities = baseCapabilities(provider: provider, model: model)
            if isVisionModel {
                capabilities.insert(.imageInput)
            }
            if model.contains("gpt-4o") || model.contains("gpt-4.1") || model.hasPrefix("o3") || model.hasPrefix("o4") {
                capabilities.insert(.fileInput)
            }
            return capabilities
        case .anthropic:
            return baseCapabilities(provider: provider, model: model).union([.imageInput, .fileInput])
        case .googleGemini:
            return baseCapabilities(provider: provider, model: model).union([.imageInput, .fileInput])
        case .openRouter:
            var capabilities = baseCapabilities(provider: provider, model: model)
            if isVisionModel {
                capabilities.insert(.imageInput)
            }
            if model.contains("claude") || model.contains("gemini") || model.contains("gpt-4") {
                capabilities.insert(.fileInput)
            }
            return capabilities
        case .perplexity:
            return baseCapabilities(provider: provider, model: model)
        case .xAI:
            return model.contains("vision")
                ? baseCapabilities(provider: provider, model: model).union([.imageInput])
                : baseCapabilities(provider: provider, model: model)
        case .mistral:
            return model.contains("pixtral")
                ? baseCapabilities(provider: provider, model: model).union([.imageInput])
                : baseCapabilities(provider: provider, model: model)
        case .groq, .deepSeek, .togetherAI, .customOpenAICompatible:
            return baseCapabilities(provider: provider, model: model)
        }
    }

    private static func baseCapabilities(
        provider: LLMProviderKind,
        model: String
    ) -> Set<TemporaryChatCapability> {
        TemporaryChatWebSearchCapabilityRegistry.capabilities(
            provider: provider,
            model: model
        ).isEmpty ? [] : [.webSearch]
    }
}

private extension LLMProviderKind {
    func normalizedBaseURL(_ rawValue: String) -> String {
        switch (self, rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) {
        case (.openAI, "https://api.openai.com"):
            defaultBaseURL
        case (.anthropic, "https://api.anthropic.com"):
            defaultBaseURL
        case (.googleGemini, "https://generativelanguage.googleapis.com"):
            defaultBaseURL
        case (.openRouter, "https://openrouter.ai/api"):
            defaultBaseURL
        case (.customOpenAICompatible, "http://localhost:11434"):
            defaultBaseURL
        default:
            rawValue
        }
    }
}
