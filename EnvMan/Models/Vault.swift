import Foundation

/// The decrypted, in memory shape of the vault file. The whole structure is
/// persisted as one blob encrypted with the device key, so nothing is written to
/// disk in plaintext. Names and memos live here so the list shows without the
/// master password; secret values are each encrypted again with the DEK.
struct VaultFile: Codable {
    var version: Int = 2
    var kdf: KDFParams
    /// DEK wrapped with the KEK from the master password: AES-GCM(KEK, DEK).
    var wrappedDEK: Data
    /// DEK wrapped with the key from the recovery key: AES-GCM(recKey, DEK).
    var recoveryKDF: KDFParams
    var wrappedDEKRecovery: Data
    var namespaces: [NamespaceData] = []
}

struct KDFParams: Codable, Equatable {
    var salt: Data
    var iterations: Int
    var algorithm: String = "pbkdf2-hmac-sha256"
}

struct NamespaceData: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// Grouping, e.g. "my-api".
    var project: String
    /// Environment within the project, e.g. "production".
    var env: String
    var created: Date = Date()
    var updated: Date = Date()
    var secrets: [SecretData] = []

    var path: String { "\(project)/\(env)" }
}

struct SecretData: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var key: String
    /// Value encrypted with the DEK: AES-GCM(DEK, plaintext). Never plaintext.
    var value: Data
    /// A non sensitive note, visible even when locked. Not encrypted with the DEK.
    var memo: String = ""
    var created: Date = Date()
    var updated: Date = Date()
}

/// A plaintext secret used only transiently in memory.
struct PlainSecret: Identifiable, Equatable {
    var id: UUID
    var key: String
    var value: String
    var memo: String = ""
}
