import SwiftUI

struct MainView: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: 240)
            Rectangle().fill(t.line).frame(width: 1)
            DetailView()
        }
        .background(t.win)
        .onAppear {
            if ui.selectedNamespace == nil || store.namespace(ui.selectedNamespace!) == nil {
                ui.selectedNamespace = store.vault?.namespaces.first?.id
            }
        }
        .onChange(of: store.isUnlocked) { _, unlocked in if !unlocked { ui.onLock() } }
    }
}
