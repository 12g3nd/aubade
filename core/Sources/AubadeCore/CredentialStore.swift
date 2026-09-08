import Foundation

/// Where secrets live.
///
/// Deliberately separate from `FileStore`: tokens must never end up in the archive, an
/// export, or a backup of the editions directory. Keeping them behind their own type means
/// there is no path by which a credential can be written to the same place as a morning.
public protocol CredentialStore: Sendable {
    func token(for account: CredentialAccount) throws -> String?
    func setToken(_ token: String?, for account: CredentialAccount) throws
}

public enum CredentialAccount: String, Sendable, CaseIterable {
    case quercus
    case personalMail
    case schoolMail
}

public enum CredentialError: Error, Equatable {
    case keychain(status: Int32)
}

/// Test double. Never used in the app.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [String: String] = [:]

    public init(tokens: [CredentialAccount: String] = [:]) {
        self.tokens = Dictionary(uniqueKeysWithValues: tokens.map { ($0.key.rawValue, $0.value) })
    }

    public func token(for account: CredentialAccount) throws -> String? {
        lock.withLock { tokens[account.rawValue] }
    }

    public func setToken(_ token: String?, for account: CredentialAccount) throws {
        lock.withLock {
            if let token { tokens[account.rawValue] = token }
            else { tokens.removeValue(forKey: account.rawValue) }
        }
    }
}
