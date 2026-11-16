import Foundation
import Security

/// Keeps the owner's Claude API key in the iPad's Keychain (this device only, not synced, not
/// in backups). The key is never written to notebooks, logs or the repository.
///
/// This is a deliberate, documented exception to the plan of keeping provider keys on a server
/// (docs/DECISIONS.md): it is for the owner's personal testing build only. Before the app is
/// offered to others, requests must go through a server that holds the key.
enum AIKeyStore {
    private static let service = "com.agentnotes.claude-api"
    private static let account = "api-key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasKey: Bool { load()?.isEmpty == false }

    @discardableResult
    static func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        delete()
        var query = baseQuery
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
