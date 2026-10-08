import Foundation
import CryptoKit
import Observation
import AppKit

@MainActor
@Observable
final class VaultStore {
    enum State { case uninitialized, locked, unlocked }
    enum ConflictPolicy: String, CaseIterable { case overwrite, skip, keepBoth }
    enum SortMode: String { case keyAsc, recent }

    struct Toast: Identifiable {
        enum Kind { case normal, clip, undo }
        let id = UUID()
        var icon: String
        var title: String
        var sub: String? = nil
        var kind: Kind = .normal
        var clipStart: Date? = nil
        var clipEnd: Date? = nil
        var undo: (() -> Void)? = nil
    }

    private(set) var vault: VaultFile?
    private(set) var sessionStart: Date?
    private(set) var sessionExpiry: Date?
    /// Updated every second while unlocked, to drive countdowns.
    private(set) var now: Date = Date()
    var sortMode: SortMode = .keyAsc
    var toast: Toast?
    var lastError: String?

    let settings: AppSettings

    @ObservationIgnored private var dek: SymmetricKey?
    @ObservationIgnored private var deviceKey: SymmetricKey?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var deletedBackup: (nsID: UUID, secret: SecretData, index: Int)?

    var state: State {
        guard vault != nil else { return .uninitialized }
        return dek == nil ? .locked : .unlocked
    }
    var isUnlocked: Bool { dek != nil }

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        bootstrap()
        installAutoLockObservers()
    }

    // MARK: Persistence

    private var fileURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("vault.enc")
    }

    func bootstrap() {
        do {
            let key = try DeviceKey.loadOrCreate()
            deviceKey = key
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                seedDemoIfRequested()
                return
            }
            let blob = try Data(contentsOf: fileURL)
            let json = try Crypto.open(blob, key: key)
            vault = try JSONDecoder().decode(VaultFile.self, from: json)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "볼트를 불러오지 못했습니다."
        }
    }

    private func persist() throws {
        guard let deviceKey, let vault else { throw CryptoError.corrupted }
        let json = try JSONEncoder().encode(vault)
        try Crypto.seal(json, key: deviceKey).write(to: fileURL, options: .atomic)
    }

    // MARK: Create, unlock, recovery, lock

    /// Creates the vault and returns the recovery key. Onboarding passes the key it
    /// already showed the user so display and storage match.
    @discardableResult
    func createVault(masterPassword: String, recoveryKey: String? = nil) throws -> String {
        guard deviceKey != nil else { throw CryptoError.corrupted }
        let dataKey = try Crypto.newKey()

        let salt = try Crypto.randomData(16)
        let kek = Crypto.deriveKey(password: masterPassword, salt: salt, iterations: Crypto.defaultIterations)
        let wrapped = try Crypto.seal(dataKey.raw, key: kek)

        let recovery = recoveryKey ?? RecoveryKey.generate()
        let rSalt = try Crypto.randomData(16)
        let rKey = Crypto.deriveKey(password: RecoveryKey.normalize(recovery), salt: rSalt, iterations: Crypto.defaultIterations)
        let rWrapped = try Crypto.seal(dataKey.raw, key: rKey)

        vault = VaultFile(
            kdf: KDFParams(salt: salt, iterations: Crypto.defaultIterations),
            wrappedDEK: wrapped,
            recoveryKDF: KDFParams(salt: rSalt, iterations: Crypto.defaultIterations),
            wrappedDEKRecovery: rWrapped,
            namespaces: []
        )
        try persist()
        dek = dataKey
        startSession()
        return recovery
    }

    func unlock(masterPassword: String) throws {
        guard let vault else { throw CryptoError.corrupted }
        let kek = Crypto.deriveKey(password: masterPassword, salt: vault.kdf.salt, iterations: vault.kdf.iterations)
        let raw = try Crypto.open(vault.wrappedDEK, key: kek)
        dek = SymmetricKey(data: raw)
        startSession()
    }

    @discardableResult
    func resetWithRecoveryKey(_ recoveryKey: String, newPassword: String) throws -> String {
        guard var vault else { throw CryptoError.corrupted }
        let rKey = Crypto.deriveKey(password: RecoveryKey.normalize(recoveryKey), salt: vault.recoveryKDF.salt, iterations: vault.recoveryKDF.iterations)
        let raw = try Crypto.open(vault.wrappedDEKRecovery, key: rKey)
        let dataKey = SymmetricKey(data: raw)

        let salt = try Crypto.randomData(16)
        let kek = Crypto.deriveKey(password: newPassword, salt: salt, iterations: Crypto.defaultIterations)
        vault.kdf = KDFParams(salt: salt, iterations: Crypto.defaultIterations)
        vault.wrappedDEK = try Crypto.seal(dataKey.raw, key: kek)

        let newRecovery = RecoveryKey.generate()
        let rSalt = try Crypto.randomData(16)
        let newRKey = Crypto.deriveKey(password: RecoveryKey.normalize(newRecovery), salt: rSalt, iterations: Crypto.defaultIterations)
        vault.recoveryKDF = KDFParams(salt: rSalt, iterations: Crypto.defaultIterations)
        vault.wrappedDEKRecovery = try Crypto.seal(dataKey.raw, key: newRKey)

        self.vault = vault
        try persist()
        dek = dataKey
        startSession()
        return newRecovery
    }

    func changeMasterPassword(current: String, new: String) throws {
        guard var vault else { throw CryptoError.corrupted }
        let oldKEK = Crypto.deriveKey(password: current, salt: vault.kdf.salt, iterations: vault.kdf.iterations)
        let raw = try Crypto.open(vault.wrappedDEK, key: oldKEK)
        let salt = try Crypto.randomData(16)
        let kek = Crypto.deriveKey(password: new, salt: salt, iterations: Crypto.defaultIterations)
        vault.kdf = KDFParams(salt: salt, iterations: Crypto.defaultIterations)
        vault.wrappedDEK = try Crypto.seal(Data(raw), key: kek)
        self.vault = vault
        try persist()
    }

    @discardableResult
    func reissueRecoveryKey(masterPassword: String) throws -> String {
        guard var vault else { throw CryptoError.corrupted }
        let kek = Crypto.deriveKey(password: masterPassword, salt: vault.kdf.salt, iterations: vault.kdf.iterations)
        let raw = try Crypto.open(vault.wrappedDEK, key: kek)
        let recovery = RecoveryKey.generate()
        let rSalt = try Crypto.randomData(16)
        let rKey = Crypto.deriveKey(password: RecoveryKey.normalize(recovery), salt: rSalt, iterations: Crypto.defaultIterations)
        vault.recoveryKDF = KDFParams(salt: rSalt, iterations: Crypto.defaultIterations)
        vault.wrappedDEKRecovery = try Crypto.seal(Data(raw), key: rKey)
        self.vault = vault
        try persist()
        return recovery
    }

    func resetEverything() {
        lock()
        vault = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    func lock() {
        dek = nil
        sessionStart = nil
        sessionExpiry = nil
        tickTask?.cancel(); tickTask = nil
    }

    private func startSession() {
        let start = Date()
        sessionStart = start
        sessionExpiry = start.addingTimeInterval(TimeInterval(settings.sessionSeconds))
        now = start
        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.isUnlocked else { return }
                self.now = Date()
                if let exp = self.sessionExpiry, Date() >= exp { self.lock(); return }
            }
        }
    }

    func touchSession() {
        guard isUnlocked else { return }
        let start = Date()
        sessionStart = start
        sessionExpiry = start.addingTimeInterval(TimeInterval(settings.sessionSeconds))
    }

    // Session display
    var sessionRemaining: Int {
        guard let exp = sessionExpiry else { return 0 }
        return max(0, Int(exp.timeIntervalSince(now).rounded(.down)))
    }
    var sessionText: String { String(format: "%d:%02d", sessionRemaining / 60, sessionRemaining % 60) }
    var sessionPct: Double {
        guard let start = sessionStart, let exp = sessionExpiry else { return 0 }
        let total = exp.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return max(0, min(1, exp.timeIntervalSince(now) / total)) * 100
    }

    // MARK: Namespaces

    var groupedNamespaces: [(project: String, items: [NamespaceData])] {
        guard let vault else { return [] }
        var order: [String] = []
        var map: [String: [NamespaceData]] = [:]
        for ns in vault.namespaces {
            if map[ns.project] == nil { order.append(ns.project) }
            map[ns.project, default: []].append(ns)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    func addNamespace(path: String) -> UUID? {
        let (p, e) = Self.parsePath(path)
        guard !e.isEmpty || !p.isEmpty else { return nil }
        let ns = NamespaceData(project: p, env: e)
        vault?.namespaces.append(ns)
        try? persist()
        return ns.id
    }

    func renameNamespace(id: UUID, path: String) {
        guard let i = idx(id) else { return }
        let (p, e) = Self.parsePath(path)
        vault?.namespaces[i].project = p
        vault?.namespaces[i].env = e
        vault?.namespaces[i].updated = Date()
        try? persist()
    }

    func deleteNamespace(id: UUID) {
        vault?.namespaces.removeAll { $0.id == id }
        try? persist()
    }

    func moveNamespace(id: UUID, by delta: Int) {
        guard var list = vault?.namespaces, let i = list.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard j >= 0, j < list.count else { return }
        list.swapAt(i, j)
        vault?.namespaces = list
        try? persist()
    }

    static func parsePath(_ path: String) -> (String, String) {
        let t = path.trimmingCharacters(in: .whitespaces)
        if let slash = t.firstIndex(of: "/") {
            let p = String(t[..<slash]).trimmingCharacters(in: .whitespaces)
            let e = String(t[t.index(after: slash)...]).trimmingCharacters(in: .whitespaces)
            return (p, e)
        }
        return (t, "")
    }

    // MARK: Secrets

    func namespace(_ id: UUID) -> NamespaceData? { vault?.namespaces.first { $0.id == id } }
    private func idx(_ id: UUID) -> Int? { vault?.namespaces.firstIndex { $0.id == id } }

    func reveal(_ secret: SecretData) throws -> String {
        guard let dek else { throw CryptoError.wrongPassword }
        let plain = try Crypto.open(secret.value, key: dek)
        touchSession()
        return String(decoding: plain, as: UTF8.self)
    }

    func upsert(namespaceID: UUID, key: String, value: String, memo: String) throws {
        guard let dek else { throw CryptoError.wrongPassword }
        guard let ni = idx(namespaceID) else { return }
        let sealed = try Crypto.seal(Data(value.utf8), key: dek)
        if let si = vault?.namespaces[ni].secrets.firstIndex(where: { $0.key == key }) {
            vault?.namespaces[ni].secrets[si].value = sealed
            vault?.namespaces[ni].secrets[si].memo = memo
            vault?.namespaces[ni].secrets[si].updated = Date()
        } else {
            vault?.namespaces[ni].secrets.append(SecretData(key: key, value: sealed, memo: memo))
        }
        try persist()
    }

    func editSecret(namespaceID: UUID, secretID: UUID, newKey: String, newValue: String, newMemo: String) throws {
        guard let dek else { throw CryptoError.wrongPassword }
        guard let ni = idx(namespaceID), let si = vault?.namespaces[ni].secrets.firstIndex(where: { $0.id == secretID }) else { return }
        vault?.namespaces[ni].secrets[si].key = newKey
        vault?.namespaces[ni].secrets[si].value = try Crypto.seal(Data(newValue.utf8), key: dek)
        vault?.namespaces[ni].secrets[si].memo = newMemo
        vault?.namespaces[ni].secrets[si].updated = Date()
        try persist()
    }

    /// Memo is not encrypted, so it can be edited while locked.
    func setMemo(namespaceID: UUID, secretID: UUID, memo: String) {
        guard let ni = idx(namespaceID), let si = vault?.namespaces[ni].secrets.firstIndex(where: { $0.id == secretID }) else { return }
        vault?.namespaces[ni].secrets[si].memo = memo
        try? persist()
    }

    func deleteSecret(namespaceID: UUID, secretID: UUID) {
        guard let ni = idx(namespaceID), let si = vault?.namespaces[ni].secrets.firstIndex(where: { $0.id == secretID }) else { return }
        let removed = vault!.namespaces[ni].secrets[si]
        deletedBackup = (namespaceID, removed, si)
        vault?.namespaces[ni].secrets.remove(at: si)
        try? persist()
        showToast(Toast(icon: "trash-2", title: "‘\(removed.key)’ 삭제됨", kind: .undo, undo: { [weak self] in self?.undoDelete() }))
    }

    private func undoDelete() {
        guard let b = deletedBackup, let ni = idx(b.nsID) else { return }
        let i = min(b.index, vault?.namespaces[ni].secrets.count ?? 0)
        vault?.namespaces[ni].secrets.insert(b.secret, at: i)
        deletedBackup = nil
        try? persist()
        toast = nil
    }

    func plainSecrets(namespaceID: UUID, ids: Set<UUID>? = nil) throws -> [PlainSecret] {
        guard let dek, let ni = idx(namespaceID), let vault else { return [] }
        return try vault.namespaces[ni].secrets
            .filter { ids == nil || ids!.contains($0.id) }
            .map { PlainSecret(id: $0.id, key: $0.key, value: String(decoding: try Crypto.open($0.value, key: dek), as: UTF8.self), memo: $0.memo) }
    }

    // MARK: dotenv paste

    struct ParsedLine: Identifiable { let id = UUID(); let key: String; let value: String; var isDup: Bool }

    func parseDotenv(_ text: String, namespaceID: UUID) -> [ParsedLine] {
        let existing = Set((namespace(namespaceID)?.secrets ?? []).map { $0.key })
        var out: [ParsedLine] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line.removeFirst("export ".count) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = Self.normalizeKey(String(line[..<eq]))
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\n", with: "\n")
            }
            if key.isEmpty { continue }
            out.append(ParsedLine(key: key, value: value, isDup: existing.contains(key)))
        }
        return out
    }

    func applyParsed(_ lines: [ParsedLine], namespaceID: UUID, policy: ConflictPolicy) throws {
        for line in lines {
            if line.isDup && policy == .skip { continue }
            let key = (line.isDup && policy == .keepBoth) ? uniqueKey(line.key, namespaceID: namespaceID) : line.key
            try upsert(namespaceID: namespaceID, key: key, value: line.value, memo: "")
        }
    }

    static func normalizeKey(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).uppercased()
            .map { ($0.isLetter || $0.isNumber) ? $0 : "_" }.reduce(into: "") { $0.append($1) }
    }

    private func uniqueKey(_ key: String, namespaceID: UUID) -> String {
        let existing = Set((namespace(namespaceID)?.secrets ?? []).map { $0.key })
        if !existing.contains(key) { return key }
        var n = 2
        while existing.contains("\(key)_\(n)") { n += 1 }
        return "\(key)_\(n)"
    }

    // MARK: Share bundle

    func exportBundle(namespaceID: UUID, ids: Set<UUID>?, sharePassword: String) throws -> Data {
        guard let ns = namespace(namespaceID) else { throw CryptoError.corrupted }
        return try ShareBundle.export(namespace: ns.path, secrets: plainSecrets(namespaceID: namespaceID, ids: ids), password: sharePassword)
    }
    func previewImport(fileData: Data, sharePassword: String) throws -> SharePayload {
        try ShareBundle.decrypt(fileData: fileData, password: sharePassword)
    }
    func applyImport(_ payload: SharePayload, into namespaceID: UUID, policy: ConflictPolicy) throws {
        guard dek != nil else { throw CryptoError.wrongPassword }
        for s in payload.secrets {
            let dup = namespace(namespaceID)?.secrets.contains { $0.key == s.key } ?? false
            if dup && policy == .skip { continue }
            let key = (dup && policy == .keepBoth) ? uniqueKey(s.key, namespaceID: namespaceID) : s.key
            try upsert(namespaceID: namespaceID, key: key, value: s.value, memo: "")
        }
    }

    // MARK: Clipboard and toast

    func copyToClipboard(_ text: String, title: String, sub: String? = nil) {
        Clipboard.copy(text, clearAfter: settings.clipboardClearSeconds)
        if settings.clipboardClearSeconds > 0 {
            let start = Date()
            showToast(Toast(icon: "circle-check", title: title, sub: sub, kind: .clip,
                            clipStart: start, clipEnd: start.addingTimeInterval(TimeInterval(settings.clipboardClearSeconds))),
                      duration: TimeInterval(settings.clipboardClearSeconds))
        } else {
            showToast(Toast(icon: "circle-check", title: title, sub: sub))
        }
    }

    func clearClipboardNow() {
        NSPasteboard.general.clearContents()
        toast = nil
    }

    var clipPct: Double {
        guard let t = toast, let s = t.clipStart, let e = t.clipEnd else { return 0 }
        let total = e.timeIntervalSince(s)
        guard total > 0 else { return 0 }
        return max(0, min(1, e.timeIntervalSince(now) / total)) * 100
    }

    func showToast(_ t: Toast, duration: TimeInterval = 3.2) {
        toast = t
        now = Date()
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            // keep ticking so clip progress animates
            let deadline = Date().addingTimeInterval(duration)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, self.toast?.id == t.id else { return }
                self.now = Date()
            }
            if self?.toast?.id == t.id { self?.toast = nil }
        }
    }

    // MARK: Auto lock

    private func installAutoLockObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; if self.settings.lockOnResign { self.lock() } }
        }
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; if self.settings.lockOnSleep { self.lock() } }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; if self.settings.lockOnScreenLock { self.lock() } }
        }
    }

    // MARK: Demo seed (verification only)

    private func seedDemoIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["ENVMAN_DEMO"] == "1", deviceKey != nil else { return }
        do {
            let recovery = try createVault(masterPassword: "demo-password")
            _ = recovery
            func add(_ p: String, _ e: String, _ pairs: [(String, String, String, Int)]) {
                guard let id = addNamespace(path: "\(p)/\(e)") else { return }
                for (k, v, m, _) in pairs { try? upsert(namespaceID: id, key: k, value: v, memo: m) }
            }
            // Obviously fake demo values (no real-secret patterns, for local preview only).
            add("my-api", "production", [
                ("DATABASE_URL", "postgres://demo:demo@db.example/app", "기본 RDS, 쓰기 가능", 3),
                ("REDIS_URL", "redis://demo@cache.example:6380", "", 12),
                ("STRIPE_SECRET_KEY", "demo-stripe-placeholder", "결제, 라이브 키", 1),
                ("OPENAI_API_KEY", "demo-openai-placeholder", "", 0),
                ("ACCESS_KEY_ID", "DEMO-ACCESS-KEY-ID", "배포 IAM 사용자", 9),
            ])
            add("my-api", "staging", [
                ("DATABASE_URL", "postgres://demo:demo@db-stg.example/app", "", 2),
                ("REDIS_URL", "redis://demo@cache-stg.example:6380", "", 2),
            ])
            add("web", "production", [
                ("NEXT_PUBLIC_API_URL", "https://api.example.com", "공개 값", 5),
                ("SESSION_SECRET", "demo-session-placeholder", "", 5),
            ])
        } catch {
            lastError = "\(error)"
        }
        #endif
    }
}

private extension SymmetricKey {
    var raw: Data { withUnsafeBytes { Data($0) } }
}
