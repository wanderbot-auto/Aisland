import Foundation
import Security

enum TemporaryChatKeychain {
    private static let service = "app.aisland.temporary-chat"
    private static let legacyAccount = "llm-api-key"

    static func loadAPIKey(for provider: LLMProviderKind) -> String {
        if let value = loadAPIKey(account: account(for: provider)) {
            return value
        }
        return loadAPIKey(account: legacyAccount) ?? ""
    }

    static func saveAPIKey(_ apiKey: String, for provider: LLMProviderKind) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteAPIKey(for: provider)
            return
        }

        let data = Data(trimmed.utf8)
        let query = baseQuery(account: account(for: provider))
        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func deleteAPIKey(for provider: LLMProviderKind) {
        SecItemDelete(baseQuery(account: account(for: provider)) as CFDictionary)
    }

    @available(*, deprecated, message: "Use provider-scoped API key methods instead.")
    static func loadAPIKey() -> String {
        loadAPIKey(for: .openAI)
    }

    @available(*, deprecated, message: "Use provider-scoped API key methods instead.")
    static func saveAPIKey(_ apiKey: String) {
        saveAPIKey(apiKey, for: .openAI)
    }

    @available(*, deprecated, message: "Use provider-scoped API key methods instead.")
    static func deleteAPIKey() {
        deleteAPIKey(for: .openAI)
    }

    private static func loadAPIKey(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func account(for provider: LLMProviderKind) -> String {
        "llm-api-key.\(provider.rawValue)"
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum TemporaryChatCredentials {
    static func loadAPIKey(
        for provider: LLMProviderKind,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        keychainLoader: @Sendable (LLMProviderKind) -> String = { TemporaryChatKeychain.loadAPIKey(for: $0) }
    ) -> String {
        #if DEBUG
        if TemporaryChatDebugCredentialStore.isEnabled(environment: environment) {
            if let value = TemporaryChatDebugCredentialStore.loadAPIKey(for: provider, environment: environment) {
                return value
            }
            return apiKeyFromEnvironment(for: provider, environment: environment) ?? ""
        }
        #endif

        if let value = apiKeyFromEnvironment(for: provider, environment: environment) {
            return value
        }

        return keychainLoader(provider)
    }

    static func saveAPIKey(
        _ apiKey: String,
        for provider: LLMProviderKind,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        keychainSaver: @Sendable (String, LLMProviderKind) -> Void = { TemporaryChatKeychain.saveAPIKey($0, for: $1) }
    ) {
        #if DEBUG
        if TemporaryChatDebugCredentialStore.isEnabled(environment: environment) {
            TemporaryChatDebugCredentialStore.saveAPIKey(apiKey, for: provider, environment: environment)
            return
        }
        #endif

        keychainSaver(apiKey, provider)
    }

    static func apiKeyFromEnvironment(
        for provider: LLMProviderKind,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        provider.apiKeyEnvironmentVariables
            .lazy
            .compactMap { environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private extension LLMProviderKind {
    var apiKeyEnvironmentVariables: [String] {
        switch self {
        case .openAI:
            ["AISLAND_OPENAI_API_KEY", "OPENAI_API_KEY"]
        case .anthropic:
            ["AISLAND_ANTHROPIC_API_KEY", "ANTHROPIC_API_KEY"]
        case .googleGemini:
            ["AISLAND_GOOGLE_GEMINI_API_KEY", "GOOGLE_API_KEY", "GEMINI_API_KEY"]
        case .openRouter:
            ["AISLAND_OPENROUTER_API_KEY", "OPENROUTER_API_KEY"]
        case .groq:
            ["AISLAND_GROQ_API_KEY", "GROQ_API_KEY"]
        case .mistral:
            ["AISLAND_MISTRAL_API_KEY", "MISTRAL_API_KEY"]
        case .perplexity:
            ["AISLAND_PERPLEXITY_API_KEY", "PERPLEXITY_API_KEY"]
        case .deepSeek:
            ["AISLAND_DEEPSEEK_API_KEY", "DEEPSEEK_API_KEY"]
        case .xAI:
            ["AISLAND_XAI_API_KEY", "XAI_API_KEY", "X_AI_API_KEY"]
        case .togetherAI:
            ["AISLAND_TOGETHER_API_KEY", "TOGETHER_API_KEY", "TOGETHERAI_API_KEY"]
        case .customOpenAICompatible:
            ["AISLAND_CUSTOM_OPENAI_API_KEY", "CUSTOM_OPENAI_API_KEY"]
        }
    }
}

#if DEBUG
enum TemporaryChatDebugCredentialStore {
    private static let storeEnvironmentKey = "AISLAND_DEV_CREDENTIAL_STORE"
    private static let pathEnvironmentKey = "AISLAND_DEV_CREDENTIAL_STORE_PATH"

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let rawValue = environment[storeEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        switch rawValue.lowercased() {
        case "1", "true", "yes", "local", "file":
            return true
        default:
            return false
        }
    }

    static func loadAPIKey(
        for provider: LLMProviderKind,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let credentials = loadCredentials(environment: environment)
        return credentials[provider.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    static func saveAPIKey(
        _ apiKey: String,
        for provider: LLMProviderKind,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = credentialsURL(environment: environment)
        var credentials = loadCredentials(environment: environment)

        if trimmed.isEmpty {
            credentials.removeValue(forKey: provider.rawValue)
        } else {
            credentials[provider.rawValue] = trimmed
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(credentials)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("Aisland failed to save debug chat credentials: \(error)")
        }
    }

    private static func loadCredentials(environment: [String: String]) -> [String: String] {
        let url = credentialsURL(environment: environment)
        guard let data = try? Data(contentsOf: url),
              let credentials = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return credentials
    }

    private static func credentialsURL(environment: [String: String]) -> URL {
        if let rawPath = environment[pathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawPath.isEmpty {
            return URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("Aisland", isDirectory: true)
            .appendingPathComponent("dev-credentials.json")
    }
}
#endif

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
