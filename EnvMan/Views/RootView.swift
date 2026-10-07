import SwiftUI

/// The full manager window. Names are always visible; values need an unlock.
struct RootView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(VaultStore.self) private var store
    @Environment(UpdateChecker.self) private var updates

    @State private var selection: UUID?
    @State private var showSettings = false
    @State private var showNewNamespace = false

    var body: some View {
        Group {
            if store.state == .uninitialized {
                VStack { Spacer(); OnboardingView(store: store); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.window)
            } else {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detail
                }
            }
        }
        .provideTheme(scheme)
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(store).environment(store.settings).environment(updates)
                .provideTheme(scheme)
        }
        .sheet(isPresented: $showNewNamespace) {
            NamespaceEditor(store: store, existing: nil).provideTheme(scheme)
        }
        .onAppear {
            if selection == nil { selection = store.vault?.namespaces.first?.id }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if updates.updateAvailable {
                updateBanner
            }
            List(selection: $selection) {
                Section {
                    ForEach(store.vault?.namespaces ?? []) { ns in
                        HStack {
                            Text(ns.name).font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(Formatting.count(ns.secrets.count))
                                .font(.system(size: 11)).foregroundStyle(theme.textMuted)
                        }
                        .tag(ns.id)
                    }
                } header: {
                    Text("네임스페이스")
                }
            }
            .listStyle(.sidebar)

            Divider().overlay(theme.divider)
            HStack(spacing: 8) {
                Button { showNewNamespace = true } label: {
                    Label("네임스페이스", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer()
                LockBadge(store: store)
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(SecondaryButtonStyle())
                .help("설정")
            }
            .padding(10)
        }
        .frame(minWidth: 240)
    }

    @ViewBuilder private var detail: some View {
        if let id = selection ?? store.vault?.namespaces.first?.id, store.namespace(id) != nil {
            SecretListView(namespaceID: id)
                .id(id)
        } else {
            EmptyHint(
                systemImage: "tray",
                title: "네임스페이스를 선택하세요",
                message: "왼쪽에서 네임스페이스를 고르거나 새로 만들어 시크릿을 담으세요."
            )
            .background(theme.window)
        }
    }

    private var updateBanner: some View {
        Button {
            if let url = updates.releaseURL { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                Text("새 버전 \(updates.latestVersion ?? "") 사용 가능")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(theme.accentSoft)
        }
        .buttonStyle(.plain)
    }
}
