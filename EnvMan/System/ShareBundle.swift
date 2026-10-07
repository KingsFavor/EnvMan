import Foundation

/// The on disk shape of a shared `.envman` file. The payload is encrypted with a
/// key derived from a share password that is independent of any vault's master
/// password. Import decrypts with the share password, then the values are
/// re-encrypted with the importing vault's own DEK before they touch disk.
struct ShareBundleFile: Codable {
    var version: Int = 1
    var kind: String = "envman.share"
    var kdf: KDFParams
    /// AES-GCM(shareKey, JSON(SharePayload)).
    var payload: Data
}

struct SharePayload: Codable {
    var namespace: String
    var secrets: [ShareSecret]
}

struct ShareSecret: Codable {
    var key: String
    var value: String
}

enum ShareBundle {
    static let fileExtension = "envman"

    /// Build the bytes of an encrypted share file from plaintext secrets.
    static func export(namespace: String, secrets: [PlainSecret], password: String) throws -> Data {
        let payload = SharePayload(
            namespace: namespace,
            secrets: secrets.map { ShareSecret(key: $0.key, value: $0.value) }
        )
        let plain = try JSONEncoder().encode(payload)
        let salt = try Crypto.randomData(16)
        let iterations = Crypto.defaultIterations
        let key = Crypto.deriveKey(password: password, salt: salt, iterations: iterations)
        let sealed = try Crypto.seal(plain, key: key)
        let bundle = ShareBundleFile(
            kdf: KDFParams(salt: salt, iterations: iterations),
            payload: sealed
        )
        return try JSONEncoder().encode(bundle)
    }

    /// Decrypt a share file with its share password. Throws `wrongPassword` on a bad
    /// password or a tampered file.
    static func decrypt(fileData: Data, password: String) throws -> SharePayload {
        let bundle: ShareBundleFile
        do {
            bundle = try JSONDecoder().decode(ShareBundleFile.self, from: fileData)
        } catch {
            throw CryptoError.corrupted
        }
        let key = Crypto.deriveKey(
            password: password,
            salt: bundle.kdf.salt,
            iterations: bundle.kdf.iterations
        )
        let plain = try Crypto.open(bundle.payload, key: key)
        guard let payload = try? JSONDecoder().decode(SharePayload.self, from: plain) else {
            throw CryptoError.corrupted
        }
        return payload
    }
}
