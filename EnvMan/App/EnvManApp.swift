import SwiftUI
import AppKit

enum ManagerWindow { static let id = "envman.manager" }

@main
struct EnvManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = VaultStore()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        // Menu bar is the primary surface. No Dock icon (LSUIElement), per the brief.
        MenuBarExtra("EnvMan", systemImage: "lock.shield") {
            MenuBarContent()
                .environment(store)
                .environment(store.settings)
                .environment(updates)
        }
        .menuBarExtraStyle(.window)

        // The full manager opens on demand from the menu bar.
        Window("EnvMan", id: ManagerWindow.id) {
            RootView()
                .environment(store)
                .environment(store.settings)
                .environment(updates)
                .frame(minWidth: 720, minHeight: 480)
                .task { updates.checkOnLaunch() }
        }
        .defaultSize(width: 860, height: 560)
        .windowResizability(.contentMinSize)
    }
}

/// Accessory activation (no Dock icon) while still letting a real window come
/// forward when the user opens the manager from the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Brings the manager window forward and activates the app. Used from the menu bar
/// because an accessory app is not frontmost by default.
@MainActor
enum WindowOpener {
    static func showManager(_ open: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        open(id: ManagerWindow.id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
