import Foundation

/// Small facts about the running build.
enum BuildInfo {
    static let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"

    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
