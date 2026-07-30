import Security
import Foundation

/// Typed interface over the macOS Security framework for storing auth credentials.
/// Uses kSecClassGenericPassword; all entries are namespaced by service ID.
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.connectme.app"

    private enum Key {
        static let accessToken  = "supabase.access_token"
        static let refreshToken = "supabase.refresh_token"
        static let userId       = "auth.user_id"
        static let userEmail    = "auth.user_email"
        static let pairId       = "pairing.pair_id"
        static let deviceId     = "device.id"
    }

    // MARK: - Auth tokens

    var accessToken: String? {
        get { read(key: Key.accessToken) }
        set { store(newValue, key: Key.accessToken) }
    }

    var refreshToken: String? {
        get { read(key: Key.refreshToken) }
        set { store(newValue, key: Key.refreshToken) }
    }

    var userId: String? {
        get { read(key: Key.userId) }
        set { store(newValue, key: Key.userId) }
    }

    var userEmail: String? {
        get { read(key: Key.userEmail) }
        set { store(newValue, key: Key.userEmail) }
    }

    // MARK: - Pairing

    var pairId: String? {
        get { read(key: Key.pairId) }
        set { store(newValue, key: Key.pairId) }
    }

    // MARK: - Device identity

    /// Stable device UUID generated once and persisted in Keychain.
    var deviceId: String {
        if let existing = read(key: Key.deviceId) { return existing }
        let new = UUID().uuidString
        store(new, key: Key.deviceId)
        return new
    }

    // MARK: - Bulk operations

    func clearAuth() {
        [Key.accessToken, Key.refreshToken, Key.userId, Key.userEmail].forEach { delete(key: $0) }
    }

    func clearAll() {
        clearAuth()
        delete(key: Key.pairId)
    }

    // MARK: - Private Security framework wrappers

    private func store(_ value: String?, key: String) {
        guard let value else { delete(key: key); return }
        let data = Data(value.utf8)

        // Try updating first; if the item doesn't exist, add it.
        var query = baseQuery(key: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private func read(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
