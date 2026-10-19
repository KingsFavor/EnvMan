import Foundation

/// The on disk shape of a whole-vault `.envman` export. Unlike a share bundle,
/// which carries only the key/value pairs of one namespace, this preserves the
/// full namespace layout and every field: folder colors, memos, created/updated
/// stamps and the per namespace `gh` form, so another install can transplant the
/// vault as-is. The payload is encrypted with a key derived from an export
/// password that is independent of any vault's master password. Import decrypts
/// with that password, then re-encrypts each value with the receiving vault's
/// own DEK before it touches disk.
struct FullExportFile: Codable {
    var version: Int = 1
    var kind: String = "envman.fullexport"
    var kdf: KDFParams
    /// AES-GCM(exportKey, JSON(FullExportPayload)).
    var payload: Data
}

struct FullExportPayload: Codable {
    var exportedAt: Date = Date()
    var appVersion: String = ""
    var namespaces: [FullNamespace] = []

    var secretCount: Int { namespaces.reduce(0) { $0 + $1.secrets.count } }
}

struct FullNamespace: Codable {
    var project: String
    var env: String
    var colorHex: String? = nil
    var created: Date = Date()
    var updated: Date = Date()
    /// The remembered `gh secret set` form for this namespace, when it had one.
    var gh: GHOptions? = nil
    var secrets: [FullSecret] = []

    var path: String { env.isEmpty ? project : "\(project)/\(env)" }
}

struct FullSecret: Codable {
    var key: String
    /// Plaintext value. Only ever present inside the encrypted payload.
    var value: String
    var memo: String = ""
    var created: Date = Date()
    var updated: Date = Date()
}

enum FullExport {
    static let fileExtension = "envman"
    static let defaultFilename = "envman-full-export.envman"

    /// Encrypt a prepared payload with an export password into the bytes of a file.
    static func seal(payload: FullExportPayload, password: String) throws -> Data {
        let plain = try JSONEncoder().encode(payload)
        let salt = try Crypto.randomData(16)
        let iterations = Crypto.defaultIterations
        let key = Crypto.deriveKey(password: password, salt: salt, iterations: iterations)
        let sealed = try Crypto.seal(plain, key: key)
        let file = FullExportFile(kdf: KDFParams(salt: salt, iterations: iterations), payload: sealed)
        return try JSONEncoder().encode(file)
    }

    /// Decrypt a full-export file with its export password. Throws `wrongPassword`
    /// on a bad password or a tampered file, and `corrupted` when the bytes are not
    /// a full-export bundle (for example, a plain share file).
    static func open(fileData: Data, password: String) throws -> FullExportPayload {
        let file: FullExportFile
        do {
            file = try JSONDecoder().decode(FullExportFile.self, from: fileData)
        } catch {
            throw CryptoError.corrupted
        }
        guard file.kind == "envman.fullexport" else { throw CryptoError.corrupted }
        let key = Crypto.deriveKey(password: password, salt: file.kdf.salt, iterations: file.kdf.iterations)
        let plain = try Crypto.open(file.payload, key: key)
        guard let payload = try? JSONDecoder().decode(FullExportPayload.self, from: plain) else {
            throw CryptoError.corrupted
        }
        return payload
    }
}
