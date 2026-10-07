import SwiftUI

/// The menu bar popover: quick unlock and one-tap copy, with a door into the
/// full manager. Width tuned for a comfortable popover.
struct MenuBarContent: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openWindow) private var openWindow
    @Environment(VaultStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var selectedNamespace: UUID?
    @State private var copiedKey: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider().overlay(theme.divider)
            content
            Divider().overlay(theme.divider)
            footer
        }
        .padding(14)
        .frame(width: 340)
        .background(theme.window)
        .provideTheme(scheme)
    }

    private var header: some View {
        HStack {
            Text("EnvMan").font(.system(size: 14, weight: .bold)).foregroundStyle(theme.textPrimary)
            Spacer()
            LockBadge(store: store)
        }
    }

    @ViewBuilder private var content: some View {
        switch store.state {
        case .uninitialized:
            OnboardingView(store: store, compact: true)
        case .locked:
            VStack(alignment: .leading, spacing: 10) {
                namespaceSummary
                UnlockView(store: store, compact: true)
            }
        case .unlocked:
            unlockedQuickCopy
        }
    }

    private var namespaceSummary: some View {
        let namespaces = store.vault?.namespaces ?? []
        return Group {
            if namespaces.isEmpty {
                Text("아직 네임스페이스가 없습니다. 관리자에서 추가하세요.")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "네임스페이스")
                    ForEach(namespaces) { ns in
                        HStack {
                            Text(ns.name).font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(Formatting.count(ns.secrets.count))
                                .font(.system(size: 11)).foregroundStyle(theme.textMuted)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var unlockedQuickCopy: some View {
        let namespaces = store.vault?.namespaces ?? []
        if namespaces.isEmpty {
            Text("관리자에서 네임스페이스와 시크릿을 추가하세요.")
                .font(.system(size: 12)).foregroundStyle(theme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Picker("네임스페이스", selection: Binding(
                    get: { selectedNamespace ?? namespaces.first?.id },
                    set: { selectedNamespace = $0 }
                )) {
                    ForEach(namespaces) { ns in Text(ns.name).tag(Optional(ns.id)) }
                }
                .labelsHidden()

                let current = selectedNamespace ?? namespaces.first?.id
                if let nsID = current, let ns = store.namespace(nsID) {
                    if ns.secrets.isEmpty {
                        Text("시크릿이 없습니다.").font(.system(size: 12)).foregroundStyle(theme.textMuted)
                    } else {
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(ns.secrets) { secret in
                                    quickRow(namespaceID: nsID, secret: secret)
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    }
                }
            }
        }
    }

    private func quickRow(namespaceID: UUID, secret: SecretData) -> some View {
        HStack(spacing: 8) {
            Text(secret.key)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.mono)
                .lineLimit(1)
            Spacer()
            Button {
                copy(secret)
            } label: {
                Image(systemName: copiedKey == secret.id ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(copiedKey == secret.id ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("값 복사")
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: theme.chipRadius, style: .continuous)
                .fill(theme.panel.opacity(0.5))
        )
    }

    private func copy(_ secret: SecretData) {
        guard let value = try? store.reveal(secret) else { return }
        Clipboard.copy(value, clearAfter: settings.clipboardClearSeconds)
        copiedKey = secret.id
        Task { try? await Task.sleep(nanoseconds: 1_200_000_000); copiedKey = nil }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                WindowOpener.showManager(openWindow)
            } label: {
                Label("관리자 열기", systemImage: "rectangle.stack")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())

            Spacer()

            if store.isUnlocked {
                Button { store.lock() } label: {
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(SecondaryButtonStyle())
                .help("지금 잠그기")
            }

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("종료")
        }
    }
}
