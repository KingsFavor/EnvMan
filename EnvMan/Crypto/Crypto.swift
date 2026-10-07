import Foundation
import CryptoKit
import CommonCrypto

enum CryptoError: Error, LocalizedError {
    case wrongPassword
    case randomFailure
    case corrupted

    var errorDescription: String? {
        switch self {
        case .wrongPassword: return "비밀번호가 올바르지 않습니다."
        case .randomFailure: return "난수 생성에 실패했습니다."
        case .corrupted: return "데이터가 손상되었습니다."
        }
    }
}

/// Symmetric primitives. Values are sealed with AES-256-GCM (authenticated), and
/// the master password is stretched with PBKDF2-HMAC-SHA256. Argon2id is the
/// preferred KDF and can replace `deriveKey` later without changing the file format
/// (the algorithm label is stored in `KDFParams`).
enum Crypto {
    static let keyByteCount = 32
    static let defaultIterations = 600_000

    static func randomData(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, count, buf.baseAddress!)
        }
        guard status == errSecSuccess else { throw CryptoError.randomFailure }
        return data
    }

    static func newKey() throws -> SymmetricKey {
        SymmetricKey(data: try randomData(keyByteCount))
    }

    /// PBKDF2-HMAC-SHA256 stretch of a password into a 256 bit key.
    static func deriveKey(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        let pw = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: keyByteCount)
        salt.withUnsafeBytes { saltBuf in
            _ = CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                pw, pw.count,
                saltBuf.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                &derived, derived.count
            )
        }
        return SymmetricKey(data: Data(derived))
    }

    /// AES-GCM seal. Returns the combined nonce + ciphertext + tag.
    static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else { throw CryptoError.corrupted }
        return combined
    }

    /// AES-GCM open. Throws `wrongPassword` when authentication fails, which is how
    /// an incorrect master password is detected (the DEK unwrap tag will not verify).
    static func open(_ combined: Data, key: SymmetricKey) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoError.wrongPassword
        }
    }
}
