import Foundation
import Observation
import AppKit

/// Quietly checks GitHub Releases for a newer version and surfaces a dismissible
/// banner. Only outbound HTTPS is used (the sole network entitlement); no
/// telemetry is sent, nothing is downloaded or installed automatically.
///
/// Three independent concerns live here:
///  1. A throttled check (at most once / 6h) on launch, plus an explicit check.
///  2. A dismissible "update available" banner with a copyable Homebrew command.
///  3. Auto-restart after an in-place update: `brew upgrade --cask` swaps the
///     bundle underneath the running process, so we watch the on-disk version
///     and relaunch into it once it changes.
@Observable
final class UpdateChecker {
    struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        let draft: Bool?
        let prerelease: Bool?
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft, prerelease
        }
    }

    // MARK: Published state

    private(set) var latestVersion: String?
    private(set) var releaseURL: URL?
    /// True while an explicit (user-initiated) check is in flight.
    private(set) var isChecking = false
    /// Transient "you're on the latest version" note after an explicit check.
    private(set) var upToDateNotice = false
    /// True briefly after the Homebrew command is copied.
    private(set) var commandCopied = false

    /// Version the user asked not to be reminded about again.
    private var dismissedVersion: String?

    /// Command a user can copy to update via Homebrew (includes `brew update`).
    let updateCommand = "brew update && brew upgrade --cask envman"

    /// Whether a newer, non-dismissed release exists. Dev builds never nag.
    var updateAvailable: Bool {
        guard !BuildInfo.isDevelopment, let latest = latestVersion else { return false }
        guard Self.isNewer(latest, than: BuildInfo.version) else { return false }
        return latest != dismissedVersion
    }

    private let endpoint = URL(string: "https://api.github.com/repos/KingsFavor/EnvMan/releases/latest")!
    private let releasesPage = URL(string: "https://github.com/KingsFavor/EnvMan/releases/latest")!

    private let lastCheckKey = "lastUpdateCheckAt"
    private let dismissedKey = "dismissedUpdateVersion"

    init() {
        dismissedVersion = UserDefaults.standard.string(forKey: dismissedKey)
    }

    // MARK: Launch

    /// Called once at launch: starts the in-place update watch and runs a
    /// throttled background check. Both are no-ops for development builds.
    func checkOnLaunch() {
        scheduleRelaunchWatch()
        Task { await check(force: false) }
    }

    // MARK: Explicit check

    /// User-initiated check. Bypasses the 6h throttle and any prior dismissal,
    /// and flashes a transient "up to date" note when nothing newer is found.
    func checkForUpdatesInteractive() {
        guard !isChecking else { return }
        Task { await check(force: true, interactive: true) }
    }

    @MainActor
    private func check(force: Bool, interactive: Bool = false) async {
        guard !BuildInfo.isDevelopment else { return }

        let now = Date().timeIntervalSince1970
        if !force {
            let last = UserDefaults.standard.double(forKey: lastCheckKey)
            if last != 0, now - last < 6 * 3600 { return }
        }
        if interactive { isChecking = true; upToDateNotice = false }
        defer { if interactive { isChecking = false } }

        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("envman", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              release.draft != true, release.prerelease != true
        else {
            if interactive { flashUpToDate() }
            return
        }

        UserDefaults.standard.set(now, forKey: lastCheckKey)
        latestVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName
        releaseURL = URL(string: release.htmlURL) ?? releasesPage

        // An explicit check clears a prior dismissal so the banner can reappear.
        if interactive {
            dismissedVersion = nil
            UserDefaults.standard.removeObject(forKey: dismissedKey)
            if !updateAvailable { flashUpToDate() }
        }
    }

    private func flashUpToDate() {
        upToDateNotice = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            upToDateNotice = false
        }
    }

    // MARK: Banner actions

    func openReleasePage() {
        NSWorkspace.shared.open(releaseURL ?? releasesPage)
    }

    func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(updateCommand, forType: .string)
        commandCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            commandCopied = false
        }
    }

    /// Hide the banner and remember not to nag about this version again.
    func dismiss() {
        if let latest = latestVersion {
            dismissedVersion = latest
            UserDefaults.standard.set(latest, forKey: dismissedKey)
        }
    }

    // MARK: In-place update auto-restart

    // Homebrew replaces the .app bundle underneath the running process, so the
    // old version keeps running until relaunched. Watch the on-disk bundle
    // version; when it no longer matches the running one, relaunch into it.

    private let launchVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    private var relaunchTimer: Timer?
    private var relaunching = false

    private func scheduleRelaunchWatch() {
        guard !BuildInfo.isDevelopment, launchVersion != nil else { return }
        relaunchTimer?.invalidate()
        relaunchTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.relaunchIfUpdated()
        }
    }

    private func relaunchIfUpdated() {
        guard !relaunching, let launchVersion else { return }
        let plistPath = Bundle.main.bundlePath + "/Contents/Info.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath),
              let onDisk = dict["CFBundleShortVersionString"] as? String,
              !onDisk.isEmpty, onDisk != launchVersion else { return }

        relaunching = true
        // Relaunch the (now-updated) bundle, but only once THIS process has
        // fully exited, otherwise `open` just reactivates the dying instance
        // and no new one launches.
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; open \"\(path)\""]
        try? proc.run()
        NSApp.terminate(nil)
    }

    /// Simple dotted numeric comparison: "0.2.0" is newer than "0.1.9".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
