import Foundation
import Observation

/// Non sensitive preferences, stored in UserDefaults. Secrets never live here.
@Observable
final class AppSettings {
    var sessionSeconds: Int { didSet { d.set(sessionSeconds, forKey: K.session) } }
    var clipboardClearSeconds: Int { didSet { d.set(clipboardClearSeconds, forKey: K.clip) } }

    var lockOnScreenLock: Bool { didSet { d.set(lockOnScreenLock, forKey: K.lockScreen) } }
    var lockOnSleep: Bool { didSet { d.set(lockOnSleep, forKey: K.lockSleep) } }
    var lockOnResign: Bool { didSet { d.set(lockOnResign, forKey: K.lockResign) } }
    var lockOnWindowClose: Bool { didSet { d.set(lockOnWindowClose, forKey: K.lockClose) } }

    var appearance: Appearance { didSet { d.set(appearance.rawValue, forKey: K.appearance) } }

    /// Last-used `gh secret set` form values, kept per namespace so each one
    /// remembers its own repo/org, environment and target. Not sensitive.
    private var ghByNamespace: [String: GHOptions]

    func ghOptions(for id: UUID) -> GHOptions { ghByNamespace[id.uuidString] ?? GHOptions() }

    func setGHOptions(_ options: GHOptions, for id: UUID) {
        ghByNamespace[id.uuidString] = options
        if let data = try? JSONEncoder().encode(ghByNamespace) { d.set(data, forKey: K.gh) }
    }

    func forgetGHOptions(for id: UUID) {
        guard ghByNamespace.removeValue(forKey: id.uuidString) != nil else { return }
        if let data = try? JSONEncoder().encode(ghByNamespace) { d.set(data, forKey: K.gh) }
    }

    static let sessionPresets: [(label: String, seconds: Int)] = [
        ("5분", 300), ("15분", 900), ("30분", 1800), ("1시간", 3600),
    ]
    static let clipPresets: [(label: String, seconds: Int)] = [
        ("끄기", 0), ("15초", 15), ("30초", 30), ("60초", 60),
    ]

    private let d = UserDefaults.standard
    private enum K {
        static let session = "session.seconds"
        static let clip = "clipboard.clearSeconds"
        static let lockScreen = "lock.onScreenLock"
        static let lockSleep = "lock.onSleep"
        static let lockResign = "lock.onResign"
        static let lockClose = "lock.onWindowClose"
        static let appearance = "appearance"
        static let gh = "gh.optionsByNamespace"
    }

    init() {
        let d = UserDefaults.standard
        sessionSeconds = d.object(forKey: K.session) as? Int ?? 900
        clipboardClearSeconds = d.object(forKey: K.clip) as? Int ?? 30
        lockOnScreenLock = d.object(forKey: K.lockScreen) as? Bool ?? true
        lockOnSleep = d.object(forKey: K.lockSleep) as? Bool ?? true
        lockOnResign = d.object(forKey: K.lockResign) as? Bool ?? false
        lockOnWindowClose = d.object(forKey: K.lockClose) as? Bool ?? false
        appearance = Appearance(rawValue: d.string(forKey: K.appearance) ?? "") ?? .system
        ghByNamespace = (d.data(forKey: K.gh)).flatMap { try? JSONDecoder().decode([String: GHOptions].self, from: $0) } ?? [:]
    }
}
