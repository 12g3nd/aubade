import Foundation
import Security

/// Credentials in the Keychain.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: the app prepares its edition when
/// opened, so a token never needs reading before the first unlock, and `ThisDeviceOnly`
/// keeps it out of iCloud Keychain and encrypted backups. A Quercus token grants read
/// access to coursework and should not travel further than the phone it was entered on.
public struct KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "app.aubade.credentials") {
        self.service = service
    }

    public func token(for account: CredentialAccount) throws -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw CredentialError.keychain(status: status)
        }
    }

    public func setToken(_ token: String?, for account: CredentialAccount) throws {
        guard let token, !token.isEmpty else {
            let status = SecItemDelete(baseQuery(account) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw CredentialError.keychain(status: status)
            }
            return
        }

        let data = Data(token.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(account) as CFDictionary, update as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = baseQuery(account)
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CredentialError.keychain(status: addStatus)
            }
        default:
            throw CredentialError.keychain(status: status)
        }
    }

    private func baseQuery(_ account: CredentialAccount) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }
}
