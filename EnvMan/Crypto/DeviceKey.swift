import Foundation
import CryptoKit
import Security

/// The device key encrypts the vault file (names and metadata) so the list can be
/// shown without the master password, while nothing is ever written to disk in
/// plaintext. It lives in the login Keychain, bound to this device, and the app
/// reads it automatically. It never leaves the machine and never unlocks values.
enum DeviceKey {
    private static let service = "com.dws.envman.deviceKey"
    private static let account = "vault"

    static func loadOrCreate() throws -> SymmetricKey {
        if let existing = try load() { return existing }
        let key = try Crypto.newKey()
        try store(key)
        return key
    }

    private static func load() throws -> SymmetricKey? {
        var query: [String: Any] = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let data = out as? Data else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw CryptoError.corrupted
        }
    }

    private static func store(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        var attrs = baseQuery()
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CryptoError.corrupted
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    #if DEBUG
    /// Test helper: forget the device key so a fresh first run can be exercised.
    static func reset() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
    #endif
}
