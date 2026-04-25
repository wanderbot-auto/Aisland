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
