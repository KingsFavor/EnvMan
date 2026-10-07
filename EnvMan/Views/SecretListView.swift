import SwiftUI
import UniformTypeIdentifiers

struct SecretListView: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(VaultStore.self) private var store
    @Environment(AppSettings.self) private var settings

    let namespaceID: UUID

    @State private var revealed: Set<UUID> = []
    @State private var revealedValues: [UUID: String] = [:]
    @State private var selected: Set<UUID> = []
    @State private var format: CopyFormat = .dotenv
    @State private var gh = GHOptions()
    @State private var showGHOptions = false

    @State private var showUnlock = false
    @State private var editingSecret: SecretData?
    @State private var showNewSecret = false
    @State private var showRenameNamespace = false
    @State private var showExport = false
    @State private var exportSelectionOnly = false
    @State private var showImport = false
    @State private var toast: String?

    private var namespace: NamespaceData? { store.namespace(namespaceID) }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(theme.divider)
            if !store.isUnlocked { lockedBanner }
            listBody
            if !selected.isEmpty { selectiveCopyBar }
        }
        .background(theme.window)
        .overlay(alignment: .bottom) { toastView }
        .sheet(isPresented: $showUnlock) {
            UnlockView(store: store).provideTheme(scheme)
                .onChange(of: store.isUnlocked) { _, unlocked in if unlocked { showUnlock = false } }
        }
        .sheet(isPresented: $showNewSecret) {
            SecretEditor(store: store, namespaceID: namespaceID, existing: nil).provideTheme(scheme)
        }
        .sheet(item: $editingSecret) { secret in
            SecretEditor(store: store, namespaceID: namespaceID, existing: secret).provideTheme(scheme)
        }
        .sheet(isPresented: $showRenameNamespace) {
            NamespaceEditor(store: store, existing: namespace).provideTheme(scheme)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(store: store, namespaceID: namespaceID,
                        secretIDs: exportSelectionOnly ? selected : nil)
                .provideTheme(scheme)
        }
        .sheet(isPresented: $showImport) {
            ImportSheet(store: store, namespaceID: namespaceID).provideTheme(scheme)
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(namespace?.name ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(Formatting.count(namespace?.secrets.count ?? 0) + " 시크릿")
                    .font(.system(size: 11)).foregroundStyle(theme.textMuted)
            }
            Spacer()
            LockBadge(store: store)
            Button {
                requireUnlock { showNewSecret = true }
            } label: {
                Label("시크릿", systemImage: "plus").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SecondaryButtonStyle())

            Menu {
                Button("가져오기 (.env)", action: importDotenvPrompt)
                Button("암호화 파일 가져오기", action: { showImport = true })
                Divider()
                Button("네임스페이스 전체 암호화 내보내기") { exportSelectionOnly = false; requireUnlock { showExport = true } }
                Divider()
                Button("네임스페이스 이름 변경") { showRenameNamespace = true }
                Button("네임스페이스 삭제", role: .destructive, action: deleteNamespace)
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var lockedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").foregroundStyle(theme.locked)
            Text("값은 가려져 있습니다. 보거나 복사하려면 해제하세요.")
                .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            Spacer()
            Button("해제") { showUnlock = true }.buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(theme.locked.opacity(0.08))
    }

    // MARK: List

    @ViewBuilder private var listBody: some View {
        if let ns = namespace, !ns.secrets.isEmpty {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(ns.secrets) { secret in row(secret) }
                }
                .padding(16)
            }
        } else {
            EmptyHint(
                systemImage: "key",
                title: "시크릿이 없습니다",
                message: "오른쪽 위의 시크릿 버튼으로 키와 값을 추가하거나 .env를 가져오세요."
            )
        }
    }

    private func row(_ secret: SecretData) -> some View {
        let isRevealed = revealed.contains(secret.id)
        let isSelected = selected.contains(secret.id)
        return Card {
            HStack(spacing: 10) {
                Button {
                    toggleSelect(secret.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15))
                        .foregroundStyle(isSelected ? theme.accent : theme.textFaint)
                }
                .buttonStyle(.plain)
                .help("선택 복사에 포함")

                VStack(alignment: .leading, spacing: 3) {
                    Text(secret.key)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.mono)
                    Text(isRevealed ? (revealedValues[secret.id] ?? "") : String(repeating: "•", count: 10))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(isRevealed ? theme.textSecondary : theme.textFaint)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                Spacer()

                Button { toggleReveal(secret) } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "가리기" : "값 보기")

                Button { copyOne(secret) } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("값 복사")

                Menu {
                    Button("값 편집") { requireUnlock { editingSecret = secret } }
                    Button("키 이름 변경") { editingSecret = secret }
                    Button("삭제", role: .destructive) { store.deleteSecret(namespaceID: namespaceID, secretID: secret.id) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    // MARK: Selective copy bar

    private var selectiveCopyBar: some View {
        VStack(spacing: 8) {
            Divider().overlay(theme.divider)
            HStack(spacing: 10) {
                Text("\(selected.count)개 선택")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.textPrimary)

                Picker("형식", selection: $format) {
                    ForEach(CopyFormat.allCases) { f in Text(f.label).tag(f) }
                }
                .labelsHidden()
                .frame(width: 110)

                if format == .gh {
                    Button { showGHOptions.toggle() } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .popover(isPresented: $showGHOptions, arrowEdge: .bottom) {
                        ghOptionsForm.frame(width: 260).padding(14).provideTheme(scheme)
                    }
                    .help("gh 옵션")
                }

                Spacer()

                if format.warnsShellHistory {
                    Label("값이 셸 기록에 남을 수 있음", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10)).foregroundStyle(theme.warning)
                }

                Button("내보내기") { exportSelectionOnly = true; requireUnlock { showExport = true } }
                    .buttonStyle(SecondaryButtonStyle())
                Button("복사") { copySelected() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(width: 80)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(theme.card)
    }

    private var ghOptionsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "gh secret set 옵션")
            TextField("레포 (owner/name)", text: $gh.repo).textFieldStyle(.roundedBorder)
            TextField("환경 (--env)", text: $gh.environment).textFieldStyle(.roundedBorder)
            Picker("대상", selection: $gh.target) {
                ForEach(GHOptions.Target.allCases) { t in Text(t.rawValue).tag(t) }
            }
            Toggle("조직 시크릿 (--org)", isOn: $gh.org)
                .font(.system(size: 12))
        }
    }

    // MARK: Toast

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(theme.accent))
                .padding(.bottom, selected.isEmpty ? 16 : 70)
                .transition(.opacity)
        }
    }

    // MARK: Actions

    private func requireUnlock(_ action: @escaping () -> Void) {
        if store.isUnlocked { action() } else { showUnlock = true }
    }

    private func toggleSelect(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func toggleReveal(_ secret: SecretData) {
        if revealed.contains(secret.id) {
            revealed.remove(secret.id)
            revealedValues[secret.id] = nil
            return
        }
        requireUnlock {
            if let value = try? store.reveal(secret) {
                revealedValues[secret.id] = value
                revealed.insert(secret.id)
            }
        }
    }

    private func copyOne(_ secret: SecretData) {
        requireUnlock {
            guard let value = try? store.reveal(secret) else { return }
            Clipboard.copy(value, clearAfter: settings.clipboardClearSeconds)
            flash("\(secret.key) 복사됨")
        }
    }

    private func copySelected() {
        requireUnlock {
            guard let plains = try? store.plainSecrets(namespaceID: namespaceID, limitedTo: selected) else { return }
            let text = ExportFormats.render(plains, as: format, gh: gh)
            Clipboard.copy(text, clearAfter: settings.clipboardClearSeconds)
            flash("\(selected.count)개를 \(format.label) 형식으로 복사")
        }
    }

    private func deleteNamespace() {
        store.deleteNamespace(id: namespaceID)
    }

    private func importDotenvPrompt() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "env") ?? .plainText, .plainText, .text]
        panel.allowsOtherFileTypes = true
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            requireUnlock { importDotenv(text) }
        }
    }

    private func importDotenv(_ text: String) {
        var added = 0
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "export ", with: "")
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\n", with: "\n")
            }
            if key.isEmpty { continue }
            try? store.upsertSecret(namespaceID: namespaceID, key: key, value: value)
            added += 1
        }
        flash("\(added)개 가져옴")
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        Task { try? await Task.sleep(nanoseconds: 1_600_000_000); withAnimation { toast = nil } }
    }
}
