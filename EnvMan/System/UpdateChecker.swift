import Foundation
import Observation

/// Quietly checks GitHub Releases for a newer version and surfaces a banner. Only
/// outbound HTTPS is used (the sole network entitlement). No telemetry is sent.
@Observable
final class UpdateChecker {
    struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private(set) var latestVersion: String?
    private(set) var releaseURL: URL?
    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.isNewer(latest, than: BuildInfo.version)
    }

    private let endpoint = URL(string: "https://api.github.com/repos/KingsFavor/EnvMan/releases/latest")!

    func checkOnLaunch() {
        Task { await check() }
    }

    func checkForUpdatesInteractive() {
        Task { await check() }
    }

    @MainActor
    private func check() async {
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data)
        else { return }
        latestVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName
        releaseURL = URL(string: release.htmlURL)
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
