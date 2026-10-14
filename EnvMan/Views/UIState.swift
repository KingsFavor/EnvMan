import SwiftUI
import Observation

/// Sections of the in-app manual. Used to deep-link the manual to a topic.
enum ManualTopic: String, CaseIterable, Identifiable {
    case overview, namespace, secrets, reveal, copy, terminalHistory, share, lock, password, appearance
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "개요"
        case .namespace: return "네임스페이스"
        case .secrets: return "시크릿 추가와 편집"
        case .reveal: return "값 보기와 복사"
        case .copy: return "선택 복사"
        case .terminalHistory: return "터미널 히스토리 삭제"
        case .share: return "내보내기와 가져오기"
        case .lock: return "잠금과 세션"
        case .password: return "비밀번호와 복구 키"
        case .appearance: return "모양"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "book-open"
        case .namespace: return "folder-lock"
        case .secrets: return "plus"
        case .reveal: return "eye"
        case .copy: return "copy"
        case .terminalHistory: return "terminal"
        case .share: return "share"
        case .lock: return "lock"
        case .password: return "key"
        case .appearance: return "palette"
        }
    }
}

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
    case manual(ManualTopic?)

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
        case .manual: return "manual"
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

    /// An action waiting on a successful unlock. When a task needs the vault
    /// open (e.g. opening the edit sheet), it stashes the follow-up here and
    /// shows the unlock sheet; the unlock sheet runs it once the vault opens,
    /// and clears it if the sheet is dismissed without unlocking.
    @ObservationIgnored var pendingAfterUnlock: (() -> Void)?

    /// Shows the unlock sheet and remembers `action` to run once unlocked.
    func requireUnlock(reason: String, then action: @escaping () -> Void) {
        pendingAfterUnlock = action
        sheet = .unlock(reason: reason)
    }

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
