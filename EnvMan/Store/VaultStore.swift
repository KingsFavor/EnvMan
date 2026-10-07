import Foundation
import CryptoKit
import Observation

/// Owns the vault: loading and saving the device-key-encrypted file, the timed
/// unlock session that holds the DEK in memory, and all reads and writes.
///
/// Locked vs unlocked:
/// - The list of namespaces and key names is available whenever the file loads
///   (it is sealed only with the device key, which the app reads automatically).
/// - Secret *values* need the DEK, which only a master password unlock recovers.
///   The DEK lives in memory for the session and is dropped on lock.
@MainActor
@Observable
final class VaultStore {
    enum State { case uninitialized, locked, unlocked }

    enum ConflictPolicy { case overwrite, skip, keepBoth }

    private(set) var vault: VaultFile?
    private(set) var sessionExpiry: Date?
    var lastError: String?

    let settings: AppSettings

    @ObservationIgnored private var dek: SymmetricKey?
    @ObservationIgnored private var deviceKey: SymmetricKey?
    @ObservationIgnored private var autoLockTask: Task<Void, Never>?

    var state: State {
        guard vault != nil else { return .uninitialized }
        return dek == nil ? .locked : .unlocked
    }
    var isUnlocked: Bool { dek != nil }

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        bootstrap()
    }

    // MARK: Load

    private var fileURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("vault.enc")
    }

    func bootstrap() {
        do {
            let key = try DeviceKey.loadOrCreate()
            deviceKey = key
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let blob = try Data(contentsOf: fileURL)
            let json = try Crypto.open(blob, key: key)
            vault = try JSONDecoder().decode(VaultFile.self, from: json)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "볼트를 불러오지 못했습니다."
        }
    }

    // MARK: Create, unlock, lock

    func createVault(masterPassword: String) throws {
        guard let deviceKey else { throw CryptoError.corrupted }
        let salt = try Crypto.randomData(16)
        let iterations = Crypto.defaultIterations
        let kek = Crypto.deriveKey(password: masterPassword, salt: salt, iterations: iterations)
        let dataKey = try Crypto.newKey()
        let wrapped = try Crypto.seal(dataKey.rawBytes, key: kek)
        var file = VaultFile(kdf: KDFParams(salt: salt, iterations: iterations), wrappedDEK: wrapped)
        file.namespaces = []
        vault = file
        try persist()
        _ = deviceKey // silence unused in release paths
        dek = dataKey
        startSession()
    }

    func unlock(masterPassword: String) throws {
        guard let vault else { throw CryptoError.corrupted }
        let kek = Crypto.deriveKey(
            password: masterPassword,
            salt: vault.kdf.salt,
            iterations: vault.kdf.iterations
        )
        let raw = try Crypto.open(vault.wrappedDEK, key: kek) // throws wrongPassword on bad tag
        dek = SymmetricKey(data: raw)
        startSession()
    }

    func lock() {
        dek = nil
        sessionExpiry = nil
        autoLockTask?.cancel()
        autoLockTask = nil
    }

    func changeMasterPassword(current: String, new: String) throws {
        guard var vault else { throw CryptoError.corrupted }
        let oldKEK = Crypto.deriveKey(password: current, salt: vault.kdf.salt, iterations: vault.kdf.iterations)
        let raw = try Crypto.open(vault.wrappedDEK, key: oldKEK)
        let salt = try Crypto.randomData(16)
        let iterations = Crypto.defaultIterations
        let newKEK = Crypto.deriveKey(password: new, salt: salt, iterations: iterations)
        vault.kdf = KDFParams(salt: salt, iterations: iterations)
        vault.wrappedDEK = try Crypto.seal(Data(raw), key: newKEK)
        self.vault = vault
        try persist()
    }

    private func startSession() {
        sessionExpiry = Date().addingTimeInterval(TimeInterval(settings.sessionSeconds))
        scheduleAutoLock()
    }

    /// Extend the session on meaningful activity (copy, reveal).
    func touchSession() {
        guard isUnlocked else { return }
        startSession()
    }

    private func scheduleAutoLock() {
        autoLockTask?.cancel()
        guard let expiry = sessionExpiry else { return }
        autoLockTask = Task { @MainActor [weak self] in
            let delay = expiry.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            self?.lock()
        }
    }

    // MARK: Namespace and key names (no session needed)

    func addNamespace(name: String) {
        guard vault != nil else { return }
        vault?.namespaces.append(NamespaceData(name: name))
        try? persist()
    }

    func renameNamespace(id: UUID, to name: String) {
        guard let i = index(ofNamespace: id) else { return }
        vault?.namespaces[i].name = name
        vault?.namespaces[i].updated = Date()
        try? persist()
    }

    func deleteNamespace(id: UUID) {
        vault?.namespaces.removeAll { $0.id == id }
        try? persist()
    }

    func renameKey(namespaceID: UUID, secretID: UUID, to key: String) {
        guard let ni = index(ofNamespace: namespaceID),
              let si = vault?.namespaces[ni].secrets.firstIndex(where: { $0.id == secretID }) else { return }
        vault?.namespaces[ni].secrets[si].key = key
        vault?.namespaces[ni].secrets[si].updated = Date()
        try? persist()
    }

    func deleteSecret(namespaceID: UUID, secretID: UUID) {
        guard let ni = index(ofNamespace: namespaceID) else { return }
        vault?.namespaces[ni].secrets.removeAll { $0.id == secretID }
        try? persist()
    }

    // MARK: Values (session needed)

    func reveal(_ secret: SecretData) throws -> String {
        guard let dek else { throw CryptoError.wrongPassword }
        let plain = try Crypto.open(secret.value, key: dek)
        touchSession()
        return String(decoding: plain, as: UTF8.self)
    }

    /// Insert or update a secret's value. Requires an unlocked session.
    func upsertSecret(namespaceID: UUID, key: String, value: String) throws {
        guard let dek else { throw CryptoError.wrongPassword }
        guard let ni = index(ofNamespace: namespaceID) else { return }
        let sealed = try Crypto.seal(Data(value.utf8), key: dek)
        if let si = vault?.namespaces[ni].secrets.firstIndex(where: { $0.key == key }) {
            vault?.namespaces[ni].secrets[si].value = sealed
            vault?.namespaces[ni].secrets[si].updated = Date()
        } else {
            vault?.namespaces[ni].secrets.append(SecretData(key: key, value: sealed))
        }
        try persist()
    }

    func plainSecrets(namespaceID: UUID, limitedTo ids: Set<UUID>? = nil) throws -> [PlainSecret] {
        guard let dek else { throw CryptoError.wrongPassword }
        guard let ni = index(ofNamespace: namespaceID), let vault else { return [] }
        let secrets = vault.namespaces[ni].secrets.filter { ids == nil || ids!.contains($0.id) }
        return try secrets.map {
            let plain = try Crypto.open($0.value, key: dek)
            return PlainSecret(id: $0.id, key: $0.key, value: String(decoding: plain, as: UTF8.self))
        }
    }

    // MARK: Encrypted export and import

    func exportBundle(namespaceID: UUID, secretIDs: Set<UUID>?, sharePassword: String) throws -> Data {
        guard let ni = index(ofNamespace: namespaceID), let vault else { throw CryptoError.corrupted }
        let plains = try plainSecrets(namespaceID: namespaceID, limitedTo: secretIDs)
        return try ShareBundle.export(
            namespace: vault.namespaces[ni].name,
            secrets: plains,
            password: sharePassword
        )
    }

    /// Decrypt a share file. The caller shows the preview, then calls `applyImport`.
    func previewImport(fileData: Data, sharePassword: String) throws -> SharePayload {
        try ShareBundle.decrypt(fileData: fileData, password: sharePassword)
    }

    /// Re-encrypt an imported payload with this vault's DEK and merge it. Requires
    /// an unlocked session.
    func applyImport(_ payload: SharePayload, into namespaceID: UUID, conflict: ConflictPolicy) throws {
        guard dek != nil else { throw CryptoError.wrongPassword }
        guard let ni = index(ofNamespace: namespaceID) else { return }
        for secret in payload.secrets {
            let existing = vault?.namespaces[ni].secrets.first { $0.key == secret.key }
            if existing != nil {
                switch conflict {
                case .skip:
                    continue
                case .overwrite:
                    try upsertSecret(namespaceID: namespaceID, key: secret.key, value: secret.value)
                case .keepBoth:
                    try upsertSecret(namespaceID: namespaceID, key: uniqueKey(secret.key, in: ni), value: secret.value)
                }
            } else {
                try upsertSecret(namespaceID: namespaceID, key: secret.key, value: secret.value)
            }
        }
    }

    // MARK: Helpers

    func namespace(_ id: UUID) -> NamespaceData? {
        vault?.namespaces.first { $0.id == id }
    }

    private func index(ofNamespace id: UUID) -> Int? {
        vault?.namespaces.firstIndex { $0.id == id }
    }

    private func uniqueKey(_ key: String, in ni: Int) -> String {
        var candidate = key + "_imported"
        var n = 2
        let existing = Set((vault?.namespaces[ni].secrets ?? []).map { $0.key })
        while existing.contains(candidate) {
            candidate = "\(key)_imported_\(n)"
            n += 1
        }
        return candidate
    }

    private func persist() throws {
        guard let deviceKey, let vault else { throw CryptoError.corrupted }
        let json = try JSONEncoder().encode(vault)
        let blob = try Crypto.seal(json, key: deviceKey)
        try blob.write(to: fileURL, options: .atomic)
    }
}

private extension SymmetricKey {
    var rawBytes: Data { withUnsafeBytes { Data($0) } }
}
