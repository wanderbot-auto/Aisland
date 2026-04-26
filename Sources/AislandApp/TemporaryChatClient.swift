import Foundation
import AISDKProvider
import AISDKProviderUtils
import SwiftAISDK
import OpenAIProvider
import OpenAICompatibleProvider
import AnthropicProvider
import GoogleProvider
import GroqProvider
import MistralProvider
import PerplexityProvider
import DeepSeekProvider
import XAIProvider
import TogetherAIProvider

struct TemporaryChatClient: Sendable {
    var skillContextProvider: TemporaryChatSkillContextProvider

    init(skillContextProvider: TemporaryChatSkillContextProvider = .live()) {
        self.skillContextProvider = skillContextProvider
    }

    func complete(messages: [TemporaryChatMessage], configuration: LLMChatConfiguration) async throws -> String {
        let stream = try stream(messages: messages, configuration: configuration)
        var content = ""
        for try await event in stream {
            if case let .text(chunk) = event {
                content.append(chunk)
            }
        }
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw TemporaryChatError.emptyResponse
        }
        return content
    }

    func stream(
        messages: [TemporaryChatMessage],
        configuration: LLMChatConfiguration
    ) throws -> AsyncThrowingStream<TemporaryChatStreamEvent, Error> {
        guard !configuration.effectiveModel.isEmpty else {
            throw TemporaryChatError.missingModel
        }

        if configuration.provider != .customOpenAICompatible,
           configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TemporaryChatError.missingAPIKey
        }

        let supportedCapabilities = TemporaryChatCapabilityRegistry.capabilities(for: configuration)
        let requiredCapabilities = messages.reduce(configuration.enabledCapabilities) { partial, message in
            partial.union(message.requiredCapabilities)
        }
        if let unsupportedCapability = requiredCapabilities.first(where: { !supportedCapabilities.contains($0) }) {
            throw TemporaryChatError.unsupportedCapability(unsupportedCapability.displayName)
        }

        let webSearchRoute = webSearchRoute(messages: messages, configuration: configuration)
        let skillContext = skillContextProvider.context(messages)
        let model = try languageModel(for: configuration)
        let result = try streamText(
            model: model,
            messages: preparedModelMessages(messages: messages, skillContext: skillContext),
            tools: tools(for: configuration, route: webSearchRoute),
            toolChoice: toolChoice(for: configuration, route: webSearchRoute)
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if !skillContext.isEmpty {
                        continuation.yield(.toolResult(TemporaryChatToolResultPart(
                            toolName: "skills",
                            summary: skillContext.displaySummary
                        )))
                    }
                    for try await part in result.fullStream {
                        switch part {
                        case let .textDelta(_, text, _):
                            continuation.yield(.text(text))
                        case let .finish(_, _, totalUsage):
                            continuation.yield(.usage(TemporaryChatUsage(
                                inputTokens: totalUsage.inputTokens,
                                outputTokens: totalUsage.outputTokens,
                                totalTokens: totalUsage.totalTokens
                            )))
                        case let .source(source):
                            continuation.yield(.source(source.temporaryChatCitation))
                        case let .toolResult(result):
                            continuation.yield(.toolResult(TemporaryChatToolResultPart(
                                toolName: result.toolName,
                                summary: result.output.temporaryChatSummary
                            )))
                        default:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func preparedModelMessages(
        messages: [TemporaryChatMessage],
        skillContext: TemporaryChatSkillContext
    ) -> [ModelMessage] {
        var modelMessages = messages.map(\.modelMessage)
        if !skillContext.isEmpty {
            modelMessages.insert(.system(SystemModelMessage(content: skillContext.systemPrompt)), at: 0)
        }
        return modelMessages
    }

    private func webSearchRoute(
        messages: [TemporaryChatMessage],
        configuration: LLMChatConfiguration
    ) -> TemporaryChatWebSearchRoute {
        guard configuration.enabledCapabilities.contains(.webSearch),
              let userMessage = messages.last(where: { $0.role == .user })?.content else {
            return .none
        }

        return TemporaryChatWebSearchRouter().route(
            userMessage: userMessage,
            mode: configuration.webSearchMode,
            provider: configuration.provider,
            model: configuration.effectiveModel,
            history: messages
        )
    }

    private func tools(
        for configuration: LLMChatConfiguration,
        route: TemporaryChatWebSearchRoute
    ) -> ToolSet? {
        guard configuration.enabledCapabilities.contains(.webSearch),
              route == .nativeProvider else {
            return nil
        }

        switch configuration.provider {
        case .openAI:
            return [
                "web_search": openaiTools.webSearch(OpenAIWebSearchArgs(
                    externalWebAccess: true,
                    searchContextSize: "medium"
                )),
            ]
        case .anthropic:
            return [
                "web_search": anthropicTools.webSearch20250305(AnthropicWebSearchOptions(maxUses: 5)),
            ]
        case .googleGemini:
            return [
                "google_search": googleTools.googleSearch(),
            ]
        case .perplexity:
            return nil
        case .openRouter, .groq, .mistral, .deepSeek, .xAI, .togetherAI, .customOpenAICompatible:
            return nil
        }
    }

    private func toolChoice(
        for configuration: LLMChatConfiguration,
        route: TemporaryChatWebSearchRoute
    ) -> ToolChoice? {
        guard route == .nativeProvider else {
            return nil
        }

        switch configuration.provider {
        case .openAI, .anthropic:
            return .tool(toolName: "web_search")
        case .googleGemini:
            return .tool(toolName: "google_search")
        case .perplexity:
            return nil
        case .openRouter, .groq, .mistral, .deepSeek, .xAI, .togetherAI, .customOpenAICompatible:
            return nil
        }
    }

    private func languageModel(for configuration: LLMChatConfiguration) throws -> any LanguageModelV3 {
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = configuration.effectiveBaseURLString
        let model = configuration.effectiveModel

        switch configuration.provider {
        case .openAI:
            return try createOpenAIProvider(settings: OpenAIProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: model)
        case .anthropic:
            return try createAnthropicProvider(settings: AnthropicProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: model)
        case .googleGemini:
            return createGoogleGenerativeAI(settings: GoogleProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: GoogleGenerativeAIModelId(rawValue: model))
        case .openRouter:
            return try createOpenAICompatibleProvider(settings: OpenAICompatibleProviderSettings(
                baseURL: baseURL,
                name: "openrouter",
                apiKey: apiKey,
                headers: [
                    "HTTP-Referer": "https://vibeisland.app",
                    "X-Title": "Aisland",
                ]
            )).languageModel(modelId: model)
        case .groq:
            return try createGroqProvider(settings: GroqProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: model)
        case .mistral:
            return try createMistralProvider(settings: MistralProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: model)
        case .perplexity:
            return try createPerplexityProvider(settings: PerplexityProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: model)
        case .deepSeek:
            return try createDeepSeekProvider(settings: DeepSeekProviderSettings(
                apiKey: apiKey,
                baseURL: baseURL
            )).languageModel(modelId: model)
        case .xAI:
            return try createXAIProvider(settings: XAIProviderSettings(
                baseURL: baseURL,
                apiKey: apiKey
            )).languageModel(modelId: model)
        case .togetherAI:
            return try createTogetherAIProvider(settings: TogetherAIProviderSettings(
                apiKey: apiKey,
                baseURL: baseURL
            )).languageModel(modelId: model)
        case .customOpenAICompatible:
            return try createOpenAICompatibleProvider(settings: OpenAICompatibleProviderSettings(
                baseURL: baseURL,
                name: "custom",
                apiKey: apiKey.isEmpty ? nil : apiKey
            )).languageModel(modelId: model)
        }
    }
}

enum TemporaryChatError: LocalizedError, Equatable {
    case missingAPIKey
    case missingModel
    case emptyResponse
    case unsupportedCapability(String)
    case attachmentTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an API key in Settings > AI Chat before sending."
        case .missingModel:
            "Choose a model before sending."
        case .emptyResponse:
            "The provider returned an empty response."
        case let .unsupportedCapability(capability):
            "The selected model does not support \(capability)."
        case let .attachmentTooLarge(filename):
            "\(filename) is too large to attach."
        }
    }
}

private extension TemporaryChatMessage {
    var modelMessage: ModelMessage {
        switch role {
        case .user:
            .user(UserModelMessage(content: userContent))
        case .assistant:
            .assistant(AssistantModelMessage(content: .text(content)))
        }
    }

    var userContent: UserContent {
        let contentParts = parts.compactMap(\.userContentPart)
        guard !contentParts.isEmpty else {
            return .text(content)
        }
        if contentParts.count == 1,
           case let .text(textPart) = contentParts[0] {
            return .text(textPart.text)
        }
        return .parts(contentParts)
    }
}

private extension TemporaryChatMessagePart {
    var userContentPart: UserContentPart? {
        switch self {
        case let .text(part):
            .text(TextPart(text: part.text))
        case let .image(part):
            .image(ImagePart(image: .data(part.data), mediaType: part.mediaType))
        case let .file(part):
            .file(FilePart(data: .data(part.data), mediaType: part.mediaType, filename: part.filename))
        case let .webCitation(part):
            .text(TextPart(text: "[Source] \(part.title)\(part.url.map { ": \($0)" } ?? "")"))
        case let .toolResult(part):
            .text(TextPart(text: "[Tool result: \(part.toolName)] \(part.summary)"))
        }
    }
}

private extension TemporaryChatCapability {
    var displayName: String {
        switch self {
        case .webSearch:
            "web search"
        case .imageInput:
            "image input"
        case .fileInput:
            "file input"
        }
    }
}

private extension LanguageModelV3Source {
    var temporaryChatCitation: TemporaryChatWebCitationPart {
        switch self {
        case let .url(_, url, title, _):
            TemporaryChatWebCitationPart(title: title ?? url, url: url)
        case let .document(_, _, title, filename, _):
            TemporaryChatWebCitationPart(title: filename ?? title)
        }
    }
}

private extension JSONValue {
    var temporaryChatSummary: String {
        switch self {
        case .null:
            "null"
        case let .bool(value):
            String(value)
        case let .number(value):
            String(value)
        case let .string(value):
            value
        case let .array(values):
            values.map(\.temporaryChatSummary).joined(separator: ", ")
        case let .object(values):
            values
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.temporaryChatSummary)" }
                .joined(separator: ", ")
        }
    }
}
