import Foundation
import Security

/// Wrapper around Security.framework for `account: "openai-api-key"` in service "com.tagarela".
final class KeychainServiceLive: KeychainService, @unchecked Sendable {
    private let service = "com.tagarela"
    private let account = "openai-api-key"
    private let access = kSecAttrAccessibleAfterFirstUnlock

    func openAIKey() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.osStatus(status) }
        guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidEncoding
        }
        return s
    }

    func setOpenAIKey(_ key: String?) throws {
        // Always delete + insert to avoid attribute races
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let delStatus = SecItemDelete(baseQuery as CFDictionary)
        if delStatus != errSecSuccess && delStatus != errSecItemNotFound {
            throw KeychainError.osStatus(delStatus)
        }
        guard let key, let data = key.data(using: .utf8) else { return }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = access
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.osStatus(addStatus) }
    }
}
