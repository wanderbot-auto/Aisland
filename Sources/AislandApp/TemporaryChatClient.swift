import Foundation

struct TemporaryChatClient: Sendable {
    var urlSession: URLSession = .shared

    func complete(messages: [TemporaryChatMessage], configuration: LLMChatConfiguration) async throws -> String {
        guard let baseURL = configuration.effectiveBaseURL else {
            throw TemporaryChatError.invalidBaseURL
        }

        guard !configuration.effectiveModel.isEmpty else {
            throw TemporaryChatError.missingModel
        }

        if configuration.provider != .customOpenAICompatible,
           configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TemporaryChatError.missingAPIKey
        }

        switch configuration.provider {
        case .openAI, .openRouter, .customOpenAICompatible:
            return try await completeOpenAICompatible(messages: messages, configuration: configuration, baseURL: baseURL)
        case .anthropic:
            return try await completeAnthropic(messages: messages, configuration: configuration, baseURL: baseURL)
        case .googleGemini:
            return try await completeGemini(messages: messages, configuration: configuration, baseURL: baseURL)
        }
    }

    private func completeOpenAICompatible(
        messages: [TemporaryChatMessage],
        configuration: LLMChatConfiguration,
        baseURL: URL
    ) async throws -> String {
        let url = endpoint(baseURL: baseURL, path: "v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if configuration.provider == .openRouter {
            request.setValue("https://vibeisland.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Aisland", forHTTPHeaderField: "X-Title")
        }

        let body = OpenAIRequest(
            model: configuration.effectiveModel,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: 0.7
        )
        request.httpBody = try JSONEncoder().encode(body)

        let response: OpenAIResponse = try await send(request)
        guard let content = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw TemporaryChatError.emptyResponse
        }
        return content
    }

    private func completeAnthropic(
        messages: [TemporaryChatMessage],
        configuration: LLMChatConfiguration,
        baseURL: URL
    ) async throws -> String {
        let url = endpoint(baseURL: baseURL, path: "v1/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = AnthropicRequest(
            model: configuration.effectiveModel,
            maxTokens: 1024,
            messages: messages.map { .init(role: $0.role == .assistant ? "assistant" : "user", content: $0.content) }
        )
        request.httpBody = try JSONEncoder().encode(body)

        let response: AnthropicResponse = try await send(request)
        let content = response.content.compactMap(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw TemporaryChatError.emptyResponse
        }
        return content
    }

    private func completeGemini(
        messages: [TemporaryChatMessage],
        configuration: LLMChatConfiguration,
        baseURL: URL
    ) async throws -> String {
        let modelPath = "models/\(configuration.effectiveModel):generateContent"
        var components = URLComponents(
            url: endpoint(baseURL: baseURL, path: "v1beta/\(modelPath)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "key", value: configuration.apiKey)]
        guard let url = components?.url else {
            throw TemporaryChatError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = GeminiRequest(contents: messages.map { message in
            GeminiContent(
                role: message.role == .assistant ? "model" : "user",
                parts: [GeminiPart(text: message.content)]
            )
        })
        request.httpBody = try JSONEncoder().encode(body)

        let response: GeminiResponse = try await send(request)
        let content = response.candidates
            .flatMap { $0.content.parts }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw TemporaryChatError.emptyResponse
        }
        return content
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TemporaryChatError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)?.prefix(300) ?? "HTTP \(httpResponse.statusCode)"
            throw TemporaryChatError.requestFailed(statusCode: httpResponse.statusCode, message: String(message))
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func endpoint(baseURL: URL, path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { partialURL, component in
            partialURL.appendingPathComponent(String(component))
        }
    }
}

enum TemporaryChatError: LocalizedError, Equatable {
    case invalidBaseURL
    case missingAPIKey
    case missingModel
    case invalidResponse
    case emptyResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Invalid LLM endpoint URL."
        case .missingAPIKey:
            "Add an API key in Settings > AI Chat before sending."
        case .missingModel:
            "Choose a model before sending."
        case .invalidResponse:
            "The provider returned an invalid response."
        case .emptyResponse:
            "The provider returned an empty response."
        case let .requestFailed(statusCode, message):
            "Request failed (HTTP \(statusCode)): \(message)"
        }
    }
}

private struct OpenAIRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct AnthropicRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct AnthropicResponse: Decodable {
    struct Content: Decodable {
        let type: String?
        let text: String?
    }

    let content: [Content]
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        let content: GeminiContent
    }

    let candidates: [Candidate]
}
