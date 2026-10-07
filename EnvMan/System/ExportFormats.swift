import Foundation

/// The copy and export formats offered from a namespace's key list.
enum CopyFormat: String, CaseIterable, Identifiable {
    case dotenv = ".env"
    case shell = "shell"
    case json = "JSON"
    case gh = "gh"

    var id: String { rawValue }

    var label: String { rawValue }

    /// Whether this format embeds plaintext values into a shell command, which can
    /// land in shell history. The UI shows a warning for these.
    var warnsShellHistory: Bool { self == .shell || self == .gh }
}

/// Options for the `gh secret set` command form.
struct GHOptions: Equatable {
    enum Target: String, CaseIterable, Identifiable {
        case actions = "actions"
        case codespaces = "codespaces"
        case dependabot = "dependabot"
        var id: String { rawValue }
    }

    var repo: String = ""          // owner/name, maps to --repo
    var environment: String = ""   // maps to --env
    var target: Target = .actions  // maps to --app
    var org: Bool = false          // maps to --org (uses repo field as org when set)
}

enum ExportFormats {
    static func render(_ secrets: [PlainSecret], as format: CopyFormat, gh: GHOptions = GHOptions()) -> String {
        switch format {
        case .dotenv:
            return secrets.map { "\($0.key)=\(escapeDotenv($0.value))" }.joined(separator: "\n")
        case .shell:
            return secrets.map { "export \($0.key)=\(shellQuote($0.value))" }.joined(separator: "\n")
        case .json:
            return json(secrets)
        case .gh:
            return secrets.map { ghCommand(key: $0.key, value: $0.value, options: gh) }.joined(separator: "\n")
        }
    }

    // MARK: Format helpers

    private static func escapeDotenv(_ value: String) -> String {
        // Quote when the value has spaces, quotes, or newlines.
        if value.contains(where: { $0 == " " || $0 == "\"" || $0 == "\n" || $0 == "#" }) {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(escaped)\""
        }
        return value
    }

    private static func shellQuote(_ value: String) -> String {
        // Single quote and escape embedded single quotes the POSIX way.
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func json(_ secrets: [PlainSecret]) -> String {
        var dict: [String: String] = [:]
        for s in secrets { dict[s.key] = s.value }
        let data = (try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func ghCommand(key: String, value: String, options: GHOptions) -> String {
        var parts = ["gh secret set", key, "--body \(shellQuote(value))"]
        if !options.repo.isEmpty {
            parts.append(options.org ? "--org \(options.repo)" : "--repo \(options.repo)")
        }
        if !options.environment.isEmpty {
            parts.append("--env \(options.environment)")
        }
        if options.target != .actions {
            parts.append("--app \(options.target.rawValue)")
        }
        return parts.joined(separator: " ")
    }
}
