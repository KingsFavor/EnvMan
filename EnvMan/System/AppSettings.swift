import Foundation
import Observation

/// Non sensitive preferences, stored in UserDefaults. Secrets never live here.
@Observable
final class AppSettings {
    /// Session duration in seconds. 0 means "until the window closes" is not used here;
    /// the smallest preset is 5 minutes. A very large value approximates "stay unlocked".
    var sessionSeconds: Int {
        didSet { defaults.set(sessionSeconds, forKey: Keys.session) }
    }
    /// Seconds before a copied value is cleared from the clipboard. 0 disables clearing.
    var clipboardClearSeconds: Int {
        didSet { defaults.set(clipboardClearSeconds, forKey: Keys.clipboard) }
    }
    /// Lock automatically when the screen locks or the machine sleeps.
    var lockOnSleep: Bool {
        didSet { defaults.set(lockOnSleep, forKey: Keys.lockOnSleep) }
    }

    static let sessionPresets: [(label: String, seconds: Int)] = [
        ("5분", 300), ("15분", 900), ("30분", 1800), ("1시간", 3600),
    ]

    static let clipboardPresets: [(label: String, seconds: Int)] = [
        ("끄기", 0), ("15초", 15), ("30초", 30), ("60초", 60),
    ]

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let session = "session.seconds"
        static let clipboard = "clipboard.clearSeconds"
        static let lockOnSleep = "lock.onSleep"
    }

    init() {
        let d = UserDefaults.standard
        sessionSeconds = d.object(forKey: Keys.session) as? Int ?? 900
        clipboardClearSeconds = d.object(forKey: Keys.clipboard) as? Int ?? 30
        lockOnSleep = d.object(forKey: Keys.lockOnSleep) as? Bool ?? true
    }
}
