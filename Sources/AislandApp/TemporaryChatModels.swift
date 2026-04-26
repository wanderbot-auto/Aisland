import Foundation

enum TemporaryChatRole: String, Codable, Sendable {
    case user
    case assistant
}

enum TemporaryChatCapability: String, CaseIterable, Identifiable, Codable, Sendable {
    case webSearch
    case imageInput
    case fileInput

    var id: String { rawValue }
}

struct TemporaryChatTextPart: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct TemporaryChatAttachmentPart: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var filename: String
    var mediaType: String
    var data: Data

    var byteCount: Int { data.count }

    init(id: UUID = UUID(), filename: String, mediaType: String, data: Data) {
        self.id = id
        self.filename = filename
        self.mediaType = mediaType
        self.data = data
    }
}

struct TemporaryChatWebCitationPart: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var url: String?

    init(id: UUID = UUID(), title: String, url: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
    }
}

struct TemporaryChatToolResultPart: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var toolName: String
    var summary: String

    init(id: UUID = UUID(), toolName: String, summary: String) {
        self.id = id
        self.toolName = toolName
        self.summary = summary
    }
}

enum TemporaryChatMessagePart: Identifiable, Codable, Equatable, Sendable {
    case text(TemporaryChatTextPart)
    case image(TemporaryChatAttachmentPart)
    case file(TemporaryChatAttachmentPart)
    case webCitation(TemporaryChatWebCitationPart)
    case toolResult(TemporaryChatToolResultPart)

    var id: UUID {
        switch self {
        case let .text(part):
            part.id
        case let .image(part):
            part.id
        case let .file(part):
            part.id
        case let .webCitation(part):
            part.id
        case let .toolResult(part):
            part.id
        }
    }

    var requiredCapability: TemporaryChatCapability? {
        switch self {
        case .image:
            .imageInput
        case .file:
            .fileInput
        case .text, .webCitation, .toolResult:
            nil
        }
    }
}

struct TemporaryChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let role: TemporaryChatRole
    let parts: [TemporaryChatMessagePart]
    let createdAt: Date

    init(id: UUID = UUID(), role: TemporaryChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.parts = content.isEmpty ? [] : [.text(TemporaryChatTextPart(text: content))]
        self.createdAt = createdAt
    }

    init(
        id: UUID = UUID(),
        role: TemporaryChatRole,
        parts: [TemporaryChatMessagePart],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.parts = parts
        self.createdAt = createdAt
    }

    var content: String {
        parts.compactMap { part in
            if case let .text(textPart) = part {
                return textPart.text
            }
            return nil
        }
        .joined(separator: "\n\n")
    }

    var isRenderable: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || parts.contains { part in
                switch part {
                case .image, .file, .webCitation, .toolResult:
                    true
                case .text:
                    false
                }
            }
    }

    var requiredCapabilities: Set<TemporaryChatCapability> {
        Set(parts.compactMap(\.requiredCapability))
    }

    func replacingContent(_ newContent: String) -> TemporaryChatMessage {
        let nonTextParts = parts.filter { part in
            if case .text = part {
                return false
            }
            return true
        }
        let textParts: [TemporaryChatMessagePart] = newContent.isEmpty
            ? []
            : [.text(TemporaryChatTextPart(text: newContent))]
        return TemporaryChatMessage(id: id, role: role, parts: textParts + nonTextParts, createdAt: createdAt)
    }

    func appendingPart(_ part: TemporaryChatMessagePart) -> TemporaryChatMessage {
        TemporaryChatMessage(id: id, role: role, parts: parts + [part], createdAt: createdAt)
    }
}

struct TemporaryChatUsage: Equatable, Sendable {
    var inputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?
}

enum TemporaryChatTokenStatsSource: String, Codable, Sendable {
    case estimated
    case provider
}

struct TemporaryChatTokenStats: Equatable, Sendable {
    var inputTokens: Int
    var contextWindow: Int
    var source: TemporaryChatTokenStatsSource

    var contextRatio: Double {
        guard contextWindow > 0 else { return 0 }
        return min(Double(inputTokens) / Double(contextWindow), 1)
    }

    var contextPercentage: Int {
        Int((contextRatio * 100).rounded())
    }

    static func estimate(
        messages: [TemporaryChatMessage],
        provider: LLMProviderKind,
        model: String
    ) -> TemporaryChatTokenStats {
        let contextWindow = TemporaryChatTokenEstimator.contextWindow(provider: provider, model: model)
        let inputTokens = TemporaryChatTokenEstimator.estimateInputTokens(messages: messages)
        return TemporaryChatTokenStats(
            inputTokens: inputTokens,
            contextWindow: contextWindow,
            source: .estimated
        )
    }

    static func providerReported(
        inputTokens: Int,
        provider: LLMProviderKind,
        model: String
    ) -> TemporaryChatTokenStats {
        TemporaryChatTokenStats(
            inputTokens: inputTokens,
            contextWindow: TemporaryChatTokenEstimator.contextWindow(provider: provider, model: model),
            source: .provider
        )
    }
}

enum TemporaryChatStreamEvent: Sendable {
    case text(String)
    case usage(TemporaryChatUsage)
    case source(TemporaryChatWebCitationPart)
    case toolResult(TemporaryChatToolResultPart)
    case searchStarted(TemporaryChatSearchRequest)
    case searchQuery(String)
    case searchCompleted([TemporaryChatSearchResult])
    case searchFailed(String)
}

enum TemporaryChatTokenEstimator {
    static func estimateInputTokens(messages: [TemporaryChatMessage]) -> Int {
        guard !messages.isEmpty else { return 0 }
        let messageOverhead = messages.count * 4
        let replyPrimer = 3
        return messageOverhead + replyPrimer + messages.reduce(0) { total, message in
            total + estimateMessageTokens(message)
        }
    }

    private static func estimateMessageTokens(_ message: TemporaryChatMessage) -> Int {
        message.parts.reduce(0) { total, part in
            switch part {
            case let .text(textPart):
                total + estimateTextTokens(textPart.text)
            case .image:
                total + 256
            case let .file(attachment):
                total + max(32, attachment.byteCount / 4)
            case let .webCitation(citation):
                total + estimateTextTokens(citation.title) + (citation.url.map(estimateTextTokens) ?? 0)
            case let .toolResult(result):
                total + estimateTextTokens(result.toolName) + estimateTextTokens(result.summary)
            }
        }
    }

    static func estimateTextTokens(_ text: String) -> Int {
        var tokens = 0
        var latinRunLength = 0

        func flushLatinRun() {
            guard latinRunLength > 0 else { return }
            tokens += max(1, Int(ceil(Double(latinRunLength) / 4.0)))
            latinRunLength = 0
        }

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                flushLatinRun()
            } else if scalar.isCJKIdeographOrKana {
                flushLatinRun()
                tokens += 1
            } else if CharacterSet.alphanumerics.contains(scalar) || scalar.value == 95 {
                latinRunLength += 1
            } else {
                flushLatinRun()
                tokens += 1
            }
        }

        flushLatinRun()
        return tokens
    }

    static func contextWindow(provider: LLMProviderKind, model rawModel: String) -> Int {
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let explicit = explicitContextWindow(in: model) {
            return explicit
        }

        if model.contains("gemini") {
            return 1_000_000
        }
        if model.contains("claude") {
            return 200_000
        }
        if model.contains("gpt-4.1") || model.contains("gpt-4o") || model.hasPrefix("o1") || model.hasPrefix("o3") || model.hasPrefix("o4") {
            return 128_000
        }
        if model.contains("mistral-small") {
            return 32_000
        }
        if model.contains("mixtral-8x7b") {
            return 32_768
        }
        if model.contains("deepseek") {
            return 64_000
        }

        switch provider {
        case .anthropic:
            return 200_000
        case .googleGemini:
            return 1_000_000
        case .mistral:
            return 128_000
        case .deepSeek:
            return 64_000
        default:
            return 128_000
        }
    }

    private static func explicitContextWindow(in model: String) -> Int? {
        if model.contains("1m") || model.contains("1000k") {
            return 1_000_000
        }
        if model.contains("200k") {
            return 200_000
        }
        if model.contains("128k") {
            return 128_000
        }
        if model.contains("64k") {
            return 64_000
        }
        if model.contains("32k") || model.contains("32768") {
            return 32_768
        }
        if model.contains("16k") {
            return 16_384
        }
        if model.contains("8k") {
            return 8_192
        }
        return nil
    }
}

private extension Unicode.Scalar {
    var isCJKIdeographOrKana: Bool {
        switch value {
        case 0x3040...0x30FF, // Hiragana and Katakana
             0x3400...0x4DBF, // CJK extension A
             0x4E00...0x9FFF, // CJK unified ideographs
             0xF900...0xFAFF, // CJK compatibility ideographs
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF:
            return true
        default:
            return false
        }
    }
}
