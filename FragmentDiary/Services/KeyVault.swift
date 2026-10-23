import CryptoKit
import Foundation
import Security

enum KeyVault {
    enum VaultError: LocalizedError {
        case keychain(OSStatus)
        /// Sealed files exist but their key doesn't (e.g. the app's keychain group changed). A fresh key would
        /// leave the old journal unreadable and get it overwritten on the next save, so none is made.
        case keyMissingForExistingJournal

        var errorDescription: String? {
            switch self {
            case .keychain(let status): "키체인을 읽지 못했어요. (\(status))"
            case .keyMissingForExistingJournal: "이 기기에서 기록을 여는 열쇠를 찾지 못했어요. 기록 파일은 지우거나 덮어쓰지 않고 그대로 두었어요."
            }
        }
    }

    private static let service = "com.jonghwa.fragmentdiary"
    private static let account = "journal-key"

    /// Creates a key only when there's nothing encrypted yet; otherwise a missing key is an error, never a reset.
    static func loadOrCreateKey() throws -> SymmetricKey {
        if let data = try readKey() {
            return SymmetricKey(data: data)
        }
        if JournalFiles.anyExist {
            throw VaultError.keyMissingForExistingJournal
        }
        return try createKey()
    }

    /// Only for "모든 기록 삭제", after the sealed files are gone.
    static func createKey() throws -> SymmetricKey {
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

/// The sealed files that need the vault key to open.
enum JournalFiles {
    static var anyExist: Bool {
        let support = URL.applicationSupportDirectory
        return ["journal.sealed", "folders.sealed"].contains { name in
            FileManager.default.fileExists(atPath: support.appending(path: name).path(percentEncoded: false))
        }
    }
}
