import Foundation

/// The decrypted, in memory shape of the vault file.
///
/// The whole structure is persisted as one blob encrypted with the device key
/// (see `VaultStore`), so nothing here is ever written to disk in plaintext. Key
/// and namespace names live here so the list can be shown without the master
/// password; secret *values* are each encrypted again with the DEK, which only a
/// master password unlock can recover.
struct VaultFile: Codable {
    var version: Int = 1
    var kdf: KDFParams
    /// DEK wrapped with the KEK derived from the master password: AES-GCM(KEK, DEK).
    var wrappedDEK: Data
    var namespaces: [NamespaceData] = []
}

struct KDFParams: Codable, Equatable {
    var salt: Data
    var iterations: Int
    /// Algorithm label, kept so a future Argon2id can be introduced without breaking old files.
    var algorithm: String = "pbkdf2-hmac-sha256"
}

struct NamespaceData: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var created: Date = Date()
    var updated: Date = Date()
    var secrets: [SecretData] = []
}

struct SecretData: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var key: String
    /// The value, encrypted with the DEK: AES-GCM(DEK, plaintext). Never plaintext.
    var value: Data
    var created: Date = Date()
    var updated: Date = Date()
}

/// A plaintext secret used only transiently in memory (reveal, copy, export).
struct PlainSecret: Identifiable, Equatable {
    var id: UUID
    var key: String
    var value: String
}
