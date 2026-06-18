import Foundation
import Security

public enum KeychainSecretStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidStoredData
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidStoredData:
            "Keychain item data is not a UTF-8 string."
        case .unexpectedStatus(let status):
            "Keychain operation failed with status \(status)."
        }
    }
}

public struct KeychainSecretStore: SecretStore {
    public init() {}

    public func read(_ ref: SecretRef) throws -> String? {
        var query = keychainQuery(for: ref)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainSecretStoreError.invalidStoredData
        }

        return value
    }

    public func write(_ value: String, for ref: SecretRef) throws {
        let data = Data(value.utf8)
        let query = keychainQuery(for: ref)
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainSecretStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainSecretStoreError.unexpectedStatus(updateStatus)
        }
    }

    public func delete(_ ref: SecretRef) throws {
        let status = SecItemDelete(keychainQuery(for: ref) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
    }

    private func keychainQuery(for ref: SecretRef) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ref.service,
            kSecAttrAccount as String: ref.account
        ]
    }
}
