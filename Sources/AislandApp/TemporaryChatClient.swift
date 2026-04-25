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
    func complete(messages: [TemporaryChatMessage], configuration: LLMChatConfiguration) async throws -> String {
        let stream = try stream(messages: messages, configuration: configuration)
        var content = ""
        for try await chunk in stream {
            content.append(chunk)
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
    ) throws -> AsyncThrowingStream<String, Error> {
        guard !configuration.effectiveModel.isEmpty else {
            throw TemporaryChatError.missingModel
        }

        if configuration.provider != .customOpenAICompatible,
           configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TemporaryChatError.missingAPIKey
        }

        let model = try languageModel(for: configuration)
        let result = try streamText(
            model: model,
            messages: messages.map(\.modelMessage)
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in result.textStream {
                        continuation.yield(chunk)
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

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an API key in Settings > AI Chat before sending."
        case .missingModel:
            "Choose a model before sending."
        case .emptyResponse:
            "The provider returned an empty response."
        }
    }
}

private extension TemporaryChatMessage {
    var modelMessage: ModelMessage {
        switch role {
        case .user:
            .user(UserModelMessage(content: .text(content)))
        case .assistant:
            .assistant(AssistantModelMessage(content: .text(content)))
        }
    }
}
