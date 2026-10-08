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
    }
}
