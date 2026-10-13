import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CopyPanel: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(UIState.self) private var ui

    let namespaceID: UUID

    @State private var showConflict = false
    @State private var pendingCopy: PendingCopy?

    private struct PendingCopy: Identifiable {
        let id = UUID()
        let target: UUID
        let targetPath: String
        let conflicts: [String]
    }

    private var selectedSecrets: [SecretData] {
        (store.namespace(namespaceID)?.secrets ?? []).filter { ui.selected.contains($0.id) }
    }

    private var otherNamespaces: [NamespaceData] {
        (store.vault?.namespaces ?? []).filter { $0.id != namespaceID }
    }

    var body: some View {
        @Bindable var ui = ui
        return VStack(spacing: 0) {
            Color.clear.frame(height: 30)
            headerRow
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    chips
                    formatSection
                    if ui.format == .gh { ghOptions }
                    previewSection
                    if ui.format.warnsShellHistory { riskyWarning }
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
            }
            footer
        }
        .frame(width: 340)
        .background(t.surface)
        // Remember the gh command form per namespace: load this namespace's last
        // values when the panel opens, and save whenever the fields change.
        .onAppear { ui.gh = settings.ghOptions(for: namespaceID) }
        .onChange(of: ui.gh) { _, new in settings.setGHOptions(new, for: namespaceID) }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("선택 복사").font(.sans(15, .semibold)).foregroundStyle(t.ink)
                Text("\(ui.selected.count)개 선택됨").font(.sans(12)).foregroundStyle(t.ink2)
            }
            Spacer()
            copyToNamespaceMenu
            IconButton(icon: "trash-2", size: 28, fontSize: 14, help: "선택한 키 삭제") { deleteSelected() }
            IconButton(icon: "x", size: 28, fontSize: 15, help: "선택 해제") { ui.selected.removeAll() }
        }
        .padding(.leading, 18).padding(.trailing, 14).padding(.bottom, 10)
        .confirmationDialog("이름이 겹치는 키가 있습니다", isPresented: $showConflict, presenting: pendingCopy) { pc in
            Button("덮어쓰고 복사", role: .destructive) { performCopy(target: pc.target, path: pc.targetPath, overwrite: true) }
            Button("겹치는 키는 건너뛰기") { performCopy(target: pc.target, path: pc.targetPath, overwrite: false) }
            Button("취소", role: .cancel) {}
        } message: { pc in
            Text("‘\(pc.targetPath)’에 같은 이름의 키가 이미 있습니다: \(pc.conflicts.joined(separator: ", "))")
        }
    }

    private var copyToNamespaceMenu: some View {
        Menu {
            if otherNamespaces.isEmpty {
                Text("다른 네임스페이스가 없습니다")
            } else {
                ForEach(otherNamespaces) { ns in
                    Button(ns.path) { startCopyTo(ns) }
                }
            }
        } label: {
            lucide("folder-input").font(.system(size: 14)).foregroundStyle(t.ink3)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
        .help("선택한 키를 다른 네임스페이스로 복사")
    }

    private var chips: some View {
        FlowLayout(spacing: 4) {
            ForEach(selectedSecrets) { s in MonoChip(text: s.key) }
        }
    }

    private var formatSection: some View {
        @Bindable var ui = ui
        return VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: "형식")
            Seg(options: CopyFormat.allCases.map { ($0, $0.label) }, selection: $ui.format, mono: true)
        }
    }

    private var ghOptions: some View {
        @Bindable var ui = ui
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                FieldLabel(text: ui.gh.org ? "조직 (org)" : "레포 (owner/name)")
                TextField("", text: $ui.gh.repo).font(.mono(12)).frame(height: 28).fieldBG()
            }
            VStack(alignment: .leading, spacing: 5) {
                FieldLabel(text: "환경 (선택, Actions 레포 전용)")
                TextField("비워 두면 레포 전체", text: $ui.gh.environment).font(.mono(12)).frame(height: 28).fieldBG()
                    .disabled(ui.gh.target != .actions || ui.gh.org).opacity(ui.gh.target != .actions || ui.gh.org ? 0.5 : 1)
            }
            VStack(alignment: .leading, spacing: 5) {
                FieldLabel(text: "대상")
                Seg(options: GHOptions.Target.allCases.map { ($0, $0.rawValue) }, selection: $ui.gh.target, height: 24, fontSize: 11.5)
            }
            Button { ui.gh.org.toggle() } label: {
                HStack {
                    Text("조직(org) 시크릿으로 설정").font(.sans(12)).foregroundStyle(t.ink)
                    Spacer()
                    Switch(on: ui.gh.org)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 1))
    }

    private var previewSection: some View {
        @Bindable var ui = ui
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                FieldLabel(text: "미리보기")
                Spacer()
                Button { ui.previewShowValues.toggle() } label: {
                    HStack(spacing: 5) {
                        lucide(ui.previewShowValues ? "eye-off" : "eye").font(.system(size: 12))
                        Text(ui.previewShowValues ? "값 가리기" : "값 보기").font(.sans(11))
                    }.foregroundStyle(t.ink2)
                }
                .buttonStyle(.plain)
                .opacity(store.isUnlocked ? 1 : 0.4).disabled(!store.isUnlocked)
            }
            ScrollView {
                Text(previewText).font(.mono(11)).foregroundStyle(t.ink).lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.side).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.line, lineWidth: 1)))
        }
    }

    private var previewText: String {
        let base: [PlainSecret]
        if store.isUnlocked, let plains = try? store.plainSecrets(namespaceID: namespaceID, ids: ui.selected) {
            base = plains
        } else {
            base = selectedSecrets.map { PlainSecret(id: $0.id, key: $0.key, value: "", memo: $0.memo) }
        }
        let show = store.isUnlocked && ui.previewShowValues
        let rendered = show ? base : base.map { var c = $0; c.value = String(repeating: "•", count: 12); return c }
        return ExportFormats.render(rendered, as: ui.format, gh: ui.gh)
    }

    private var riskyWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            lucide("triangle-alert").font(.system(size: 15)).foregroundStyle(t.warn).padding(.top, 1)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("값이 셸 기록에 남을 수 있습니다").font(.sans(12.5, .semibold)).foregroundStyle(t.warn)
                    Text("이 명령에는 값이 그대로 들어 있습니다. 터미널에 붙여넣어 실행하면 기록에 남을 수 있으니, 실행 후 기록에서 지우세요.")
                        .font(.sans(11.5)).foregroundStyle(t.ink2).lineSpacing(3)
                }
                GhostButton(title: "터미널 히스토리 삭제 방법", icon: "terminal", height: 26, hpad: 10, fontSize: 12) {
                    ui.sheet = .manual(.terminalHistory)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(t.warnSoft).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.warnLine, lineWidth: 1)))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                GhostButton(title: "파일로 저장", icon: "file-down", height: 32, hpad: 12, fontSize: 12.5) { save() }
                AccentButton(title: "복사", icon: "copy", shortcut: "⌘⇧C", height: 32, hpad: 12, fontSize: 13) { copy() }
                    .frame(maxWidth: .infinity)
            }
            if settings.clipboardClearSeconds > 0 {
                Text("복사한 내용은 \(settings.clipboardClearSeconds)초 후 클립보드에서 지워집니다.")
                    .font(.sans(11)).foregroundStyle(t.ink3)
            }
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 16)
        .overlay(alignment: .top) { Rectangle().fill(t.line).frame(height: 1) }
    }

    private func renderReal() -> String? {
        guard store.isUnlocked, let plains = try? store.plainSecrets(namespaceID: namespaceID, ids: ui.selected) else { return nil }
        return ExportFormats.render(plains, as: ui.format, gh: ui.gh)
    }

    private func copy() {
        guard let text = renderReal() else { ui.sheet = .unlock(reason: "값을 복사하려면 잠금을 해제하세요."); return }
        store.copyToClipboard(text, title: "\(ui.selected.count)개를 \(ui.format.label) 형식으로 복사")
    }

    private func deleteSelected() {
        let ids = ui.selected
        guard !ids.isEmpty else { return }
        store.deleteSecrets(namespaceID: namespaceID, ids: ids)
        ui.selected.removeAll()
        ui.revealed.subtract(ids)
        for id in ids { ui.revealedValues[id] = nil }
    }

    private func startCopyTo(_ ns: NamespaceData) {
        guard !ui.selected.isEmpty else { return }
        let conflicts = store.conflictingKeys(ids: ui.selected, from: namespaceID, to: ns.id)
        if conflicts.isEmpty {
            performCopy(target: ns.id, path: ns.path, overwrite: false)
        } else {
            pendingCopy = PendingCopy(target: ns.id, targetPath: ns.path, conflicts: conflicts)
            showConflict = true
        }
    }

    private func performCopy(target: UUID, path: String, overwrite: Bool) {
        let r = store.copySecrets(ids: ui.selected, from: namespaceID, to: target, overwrite: overwrite)
        let title = r.copied > 0 ? "\(r.copied)개를 ‘\(path)’로 복사했습니다" : "복사한 키가 없습니다"
        let sub = r.skipped > 0 ? "이름이 겹치는 \(r.skipped)개는 건너뛰었습니다" : nil
        store.showToast(VaultStore.Toast(icon: "folder-input", title: title, sub: sub))
    }

    private func save() {
        guard let text = renderReal() else { ui.sheet = .unlock(reason: "값을 저장하려면 잠금을 해제하세요."); return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = ui.format == .json ? "secrets.json" : (ui.format == .dotenv ? ".env" : "secrets.txt")
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.minX + maxW, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
