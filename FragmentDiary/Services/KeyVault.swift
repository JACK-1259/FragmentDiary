import CryptoKit
import Foundation
import Security

enum KeyVault {
    enum VaultError: Error {
        case keychain(OSStatus)
    }

    private static let service = "com.jonghwa.fragmentdiary"
    private static let account = "journal-key"

    static func loadOrCreateKey() throws -> SymmetricKey {
        if let data = try readKey() {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        var attributes = baseQuery
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        // Not ThisDeviceOnly: the key must travel with encrypted device backups, or a restored phone can't read its journal.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try readKey() {
            return SymmetricKey(data: existing)
        }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return key
    }

    static func deleteKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func readKey() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return result as? Data
    }
}
