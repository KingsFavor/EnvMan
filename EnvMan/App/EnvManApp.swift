import SwiftUI
import AppKit

enum ManagerWindow { static let id = "envman.main" }

@main
struct EnvManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = VaultStore()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        // A regular windowed application. A single main window holds the manager.
        Window("EnvMan", id: ManagerWindow.id) {
            RootView()
                .environment(store)
                .environment(store.settings)
                .environment(updates)
                .frame(minWidth: 760, minHeight: 500)
                .task { updates.checkOnLaunch() }
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("잠그기") { store.lock() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

/// Keeps the single window reachable: a click on the Dock icon brings it back if
/// it was closed, like a normal Mac app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}
