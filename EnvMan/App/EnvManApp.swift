import SwiftUI
import AppKit

enum ManagerWindow { static let id = "envman.main" }

@main
struct EnvManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = VaultStore()
    @State private var ui = UIState()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        Window("EnvMan", id: ManagerWindow.id) {
            RootView()
                .environment(store)
                .environment(store.settings)
                .environment(ui)
                .environment(updates)
                .frame(minWidth: 900, minHeight: 620)
                .preferredColorScheme(store.settings.appearance.colorScheme)
                .task { updates.checkOnLaunch() }
        }
        .defaultSize(width: 1120, height: 760)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands { AppCommands(store: store, ui: ui) }
    }
}

struct AppCommands: Commands {
    let store: VaultStore
    let ui: UIState

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("설정…") { ui.sheet = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {
            Button("시크릿 추가…") {
                if store.isUnlocked { ui.sheet = .add } else { ui.sheet = .unlock(reason: "시크릿을 추가하려면 잠금을 해제하세요.") }
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(store.state == .uninitialized || ui.selectedNamespace == nil)
        }
        CommandMenu("금고") {
            Button("잠금 해제…") { ui.sheet = .unlock(reason: "값을 보거나 복사하려면 마스터 비밀번호를 입력하세요.") }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(store.state != .locked)
            Button("지금 잠그기") { store.lock(); ui.onLock() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!store.isUnlocked)
        }
    }
}

/// A regular windowed app that reopens its window from the Dock.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain { window.makeKeyAndOrderFront(nil) }
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}
