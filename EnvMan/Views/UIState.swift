import SwiftUI
import Observation

enum ActiveSheet: Identifiable, Equatable {
    case unlock(reason: String)
    case recovery
    case add
    case edit(UUID)
    case paste
    case deleteNamespace(UUID)
    case settings
    case export
    case importFile
    case changePassword
    case reissueRecovery

    var id: String {
        switch self {
        case .unlock: return "unlock"
        case .recovery: return "recovery"
        case .add: return "add"
        case .edit(let id): return "edit-\(id)"
        case .paste: return "paste"
        case .deleteNamespace(let id): return "delns-\(id)"
        case .settings: return "settings"
        case .export: return "export"
        case .importFile: return "import"
        case .changePassword: return "changepw"
        case .reissueRecovery: return "reissue"
        }
    }
}

/// Shared UI state for the main window.
@MainActor
@Observable
final class UIState {
    var selectedNamespace: UUID?
    var query: String = ""
    var selected: Set<UUID> = []
    var revealed: Set<UUID> = []
    var revealedValues: [UUID: String] = [:]
    var format: CopyFormat = .dotenv
    var gh = GHOptions()
    var previewShowValues = false
    var sheet: ActiveSheet?

    func selectNamespace(_ id: UUID?) {
        selectedNamespace = id
        selected.removeAll()
        revealed.removeAll()
        revealedValues.removeAll()
        query = ""
    }

    func onLock() {
        revealed.removeAll()
        revealedValues.removeAll()
    }
}
