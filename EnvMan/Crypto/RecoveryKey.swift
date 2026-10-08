import Foundation

/// A human transcribable recovery key: 6 groups of 4 characters from an
/// unambiguous alphabet (no I, O, 0, 1). 24 characters give 120 bits of entropy.
enum RecoveryKey {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let groups = 6
    static let groupLen = 4

    /// A new formatted recovery key, e.g. "A7KD-9F2M-...".
    static func generate() -> String {
        let count = groups * groupLen
        let bytes = (try? Crypto.randomData(count)) ?? Data(repeating: 0, count: count)
        let chars = bytes.map { alphabet[Int($0) % alphabet.count] }
        let text = String(chars)
        return stride(from: 0, to: text.count, by: groupLen).map { i in
            let start = text.index(text.startIndex, offsetBy: i)
            let end = text.index(start, offsetBy: groupLen)
            return String(text[start..<end])
        }.joined(separator: "-")
    }

    /// The groups, for the display grid.
    static func grid(_ key: String) -> [String] {
        key.split(separator: "-").map(String.init)
    }

    /// Strip formatting so the same key typed with or without dashes derives the
    /// same key material.
    static func normalize(_ input: String) -> String {
        input.uppercased().filter { alphabet.contains($0) }
    }
}
