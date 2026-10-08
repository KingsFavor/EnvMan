import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        let t = Theme(scheme: scheme)
        return ZStack {
            t.win.ignoresSafeArea()
            Group {
                if store.state == .uninitialized {
                    OnboardingView()
                } else {
                    MainView()
                }
            }
        }
        .environment(\.theme, t)
        .overlay(alignment: .bottom) { ToastView() }
        .sheet(item: $ui.sheet) { sheet in
            sheetView(sheet).environment(\.theme, t)
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .unlock(let reason): UnlockSheet(reason: reason, startInRecovery: false)
        case .recovery: UnlockSheet(reason: "", startInRecovery: true)
        case .add: AddSheet(paste: false)
        case .edit(let id): AddSheet(paste: false, editing: id)
        case .paste: AddSheet(paste: true)
        case .deleteNamespace(let id): DeleteNamespaceSheet(namespaceID: id)
        case .settings: SettingsSheet()
        case .export: ShareSheet(mode: .export)
        case .importFile: ShareSheet(mode: .importFile)
        case .changePassword: ChangePasswordSheet()
        case .reissueRecovery: ReissueRecoverySheet()
        }
    }
}
