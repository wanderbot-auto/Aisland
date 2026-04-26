import Foundation

enum TemporaryChatWebSearchMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case on
    case off

    var id: String { rawValue }

    var next: TemporaryChatWebSearchMode {
        switch self {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
    }
}

enum TemporaryChatWebSearchCapability: String, CaseIterable, Codable, Sendable {
    case nativeWebSearch
    case toolDrivenWebSearch
    case contextInjectedWebSearch
}

enum TemporaryChatSearchFreshness: String, Codable, Sendable {
    case auto
    case day
    case week
    case month
    case year
}

struct TemporaryChatSearchRequest: Equatable, Codable, Sendable {
    var query: String
    var freshness: TemporaryChatSearchFreshness
    var maxResults: Int

    init(
        query: String,
        freshness: TemporaryChatSearchFreshness = .auto,
        maxResults: Int = 5
    ) {
        self.query = query
        self.freshness = freshness
        self.maxResults = max(1, maxResults)
    }
}

struct TemporaryChatSearchResult: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var title: String
    var url: String
    var snippet: String
    var publishedAt: Date?
    var retrievedAt: Date
    var confidence: Double

    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        snippet: String,
        publishedAt: Date? = nil,
        retrievedAt: Date = Date(),
        confidence: Double = 0.5
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publishedAt = publishedAt
        self.retrievedAt = retrievedAt
        self.confidence = min(max(confidence, 0), 1)
    }

    var citation: TemporaryChatWebCitationPart {
        TemporaryChatWebCitationPart(title: title.isEmpty ? url : title, url: url)
    }
}

protocol TemporaryChatSearchService: Sendable {
    func search(_ request: TemporaryChatSearchRequest) async throws -> [TemporaryChatSearchResult]
}

enum TemporaryChatWebSearchRoute: Equatable, Sendable {
    case none
    case nativeProvider
    case appTool
    case preSearchContext(TemporaryChatSearchRequest)
}

struct TemporaryChatWebSearchRouter: Sendable {
    func route(
        userMessage: String,
        mode: TemporaryChatWebSearchMode,
        provider: LLMProviderKind,
        model: String,
        history: [TemporaryChatMessage] = []
    ) -> TemporaryChatWebSearchRoute {
        guard mode != .off else {
            return .none
        }

        let query = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return .none
        }

        let shouldSearch = mode == .on || Self.shouldSearchInAutoMode(userMessage: query, history: history)
        guard shouldSearch else {
            return .none
        }

        let capabilities = TemporaryChatWebSearchCapabilityRegistry.capabilities(
            provider: provider,
            model: model
        )
        if capabilities.contains(.nativeWebSearch) {
            return .nativeProvider
        }
        if capabilities.contains(.toolDrivenWebSearch) {
            return .appTool
        }
        if capabilities.contains(.contextInjectedWebSearch) {
            return .preSearchContext(TemporaryChatSearchRequest(
                query: query,
                freshness: Self.freshness(for: query),
                maxResults: 5
            ))
        }
        return .none
    }

    static func shouldSearchInAutoMode(
        userMessage: String,
        history: [TemporaryChatMessage] = []
    ) -> Bool {
        let message = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return false
        }

        let normalized = message.lowercased()
        if containsAny(normalized, in: explicitSearchTriggers) {
            return true
        }
        if containsAny(normalized, in: sensitiveLocalOnlyHints) {
            return false
        }
        if containsAny(normalized, in: freshnessTriggers) {
            return true
        }
        if normalized.contains("http://") || normalized.contains("https://") {
            return true
        }
        return false
    }

    static func freshness(for query: String) -> TemporaryChatSearchFreshness {
        let normalized = query.lowercased()
        if containsAny(normalized, in: dayFreshnessTriggers) {
            return .day
        }
        if containsAny(normalized, in: weekFreshnessTriggers) {
            return .week
        }
        if containsAny(normalized, in: yearFreshnessTriggers) {
            return .year
        }
        return .auto
    }

    private static func containsAny(_ text: String, in triggers: [String]) -> Bool {
        triggers.contains { text.contains($0) }
    }

    private static let explicitSearchTriggers = [
        "search",
        "web search",
        "look up",
        "lookup",
        "google",
        "browse",
        "online",
        "official site",
        "official docs",
        "查一下",
        "查询",
        "联网",
        "搜索",
        "搜一下",
        "官网",
        "网上",
    ]

    private static let freshnessTriggers = [
        "latest",
        "current",
        "today",
        "yesterday",
        "tomorrow",
        "this week",
        "news",
        "price",
        "release",
        "version",
        "changelog",
        "breaking changes",
        "最新",
        "今天",
        "昨天",
        "明天",
        "本周",
        "新闻",
        "价格",
        "报价",
        "版本",
        "发布",
        "更新",
    ]

    private static let sensitiveLocalOnlyHints = [
        "password",
        "api key",
        "secret",
        "token",
        "private key",
        "密码",
        "密钥",
        "令牌",
        "私钥",
        "隐私",
    ]

    private static let dayFreshnessTriggers = [
        "today",
        "yesterday",
        "tomorrow",
        "breaking",
        "right now",
        "今天",
        "昨天",
        "明天",
        "刚刚",
        "实时",
    ]

    private static let weekFreshnessTriggers = [
        "this week",
        "past week",
        "last week",
        "本周",
        "这周",
        "上周",
    ]

    private static let yearFreshnessTriggers = [
        "this year",
        "2026",
        "今年",
    ]
}

enum TemporaryChatWebSearchCapabilityRegistry {
    static func capabilities(for configuration: LLMChatConfiguration) -> Set<TemporaryChatWebSearchCapability> {
        capabilities(provider: configuration.provider, model: configuration.effectiveModel)
    }

    static func capabilities(
        provider: LLMProviderKind,
        model rawModel: String
    ) -> Set<TemporaryChatWebSearchCapability> {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch provider {
        case .openAI, .anthropic, .googleGemini, .perplexity:
            return [.nativeWebSearch]
        case .openRouter:
            if model.contains("perplexity") || model.contains("sonar") {
                return [.nativeWebSearch]
            }
            return [.toolDrivenWebSearch, .contextInjectedWebSearch]
        case .groq, .mistral, .deepSeek, .xAI, .togetherAI, .customOpenAICompatible:
            return [.contextInjectedWebSearch]
        }
    }
}
