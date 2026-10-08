import SwiftUI

struct Sidebar: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    @State private var creating = false
    @State private var newText = ""
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @FocusState private var focusNew: Bool
    @FocusState private var focusRename: Bool

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 30) // room for the traffic lights
            logoRow
            header
            list
            bottom
        }
        .background(t.side)
    }

    private var logoRow: some View {
        HStack(spacing: 10) {
            Image("BrandMark").resizable().interpolation(.high).scaledToFit().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("EnvMan").font(.wordmark(17)).foregroundStyle(t.ink)
                Text("이 Mac에만 저장됨").font(.sans(11)).foregroundStyle(t.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.bottom, 14)
    }

    private var header: some View {
        HStack {
            Text("네임스페이스").font(.sans(11, .semibold)).foregroundStyle(t.ink3)
            Spacer()
            IconButton(icon: "plus", size: 22, fontSize: 14, help: "새 네임스페이스") {
                creating = true; newText = ""; DispatchQueue.main.async { focusNew = true }
            }
        }
        .padding(.leading, 18).padding(.trailing, 10).padding(.vertical, 6)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.groupedNamespaces, id: \.project) { group in
                    VStack(alignment: .leading, spacing: 1) {
                        // Only show the project subheader when it actually groups
                        // more than one namespace; a lone namespace shows on its own.
                        if group.items.count > 1 {
                            Text(group.project.isEmpty ? "기타" : group.project)
                                .font(.mono(11, .medium)).foregroundStyle(t.ink3)
                                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)
                            ForEach(group.items) { ns in row(ns, label: ns.env.isEmpty ? ns.project : ns.env) }
                        } else if let ns = group.items.first {
                            row(ns, label: ns.env.isEmpty ? ns.project : ns.path)
                        }
                    }
                }
                if creating { newNsInput }
            }
            .padding(.horizontal, 8).padding(.bottom, 12).padding(.top, 2)
        }
    }

    private func row(_ ns: NamespaceData, label: String) -> some View {
        let active = ui.selectedNamespace == ns.id
        return Group {
            if renamingID == ns.id {
                TextField("", text: $renameText)
                    .textFieldStyle(.plain).font(.sans(13)).focused($focusRename)
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 7).fill(t.field).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.accent, lineWidth: 1)))
                    .onSubmit { commitRename(ns) }
                    .onExitCommand { renamingID = nil }
            } else {
                RowButton(active: active, ns: ns, label: label,
                          onSelect: { ui.selectNamespace(ns.id) },
                          onRename: { renamingID = ns.id; renameText = ns.path; DispatchQueue.main.async { focusRename = true } },
                          onUp: { store.moveNamespace(id: ns.id, by: -1) },
                          onDown: { store.moveNamespace(id: ns.id, by: 1) },
                          onDelete: { ui.sheet = .deleteNamespace(ns.id) })
            }
        }
    }

    private var newNsInput: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("프로젝트/환경 (예: my-api/dev)", text: $newText)
                .textFieldStyle(.plain).font(.mono(12)).focused($focusNew)
                .padding(.horizontal, 10).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(t.field).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.accent, lineWidth: 1)))
                .onSubmit {
                    if let id = store.addNamespace(path: newText) { ui.selectNamespace(id) }
                    creating = false
                }
                .onExitCommand { creating = false }
            Text("Enter로 만들기, Esc로 취소").font(.sans(11)).foregroundStyle(t.ink3).padding(.horizontal, 4).padding(.top, 6)
        }
    }

    private func commitRename(_ ns: NamespaceData) {
        if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
            store.renameNamespace(id: ns.id, path: renameText)
        }
        renamingID = nil
    }

    // MARK: Bottom

    @ViewBuilder private var bottom: some View {
        VStack(spacing: 8) {
            if store.isUnlocked { sessionCard } else { lockedCard }
            Button { ui.sheet = .settings } label: {
                HStack(spacing: 8) {
                    lucide("settings").font(.system(size: 14)).foregroundStyle(t.ink2)
                    Text("설정").font(.sans(13)).foregroundStyle(t.ink2)
                    Spacer()
                    Text("⌘,").font(.sans(11)).foregroundStyle(t.ink3)
                }
                .padding(.horizontal, 8).frame(height: 28).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .padding(10)
        .overlay(alignment: .top) { Rectangle().fill(t.line).frame(height: 1) }
    }

    private var sessionCard: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    lucide("lock-open").font(.system(size: 14))
                    Text("열림").font(.sans(13, .semibold))
                }.foregroundStyle(t.accentText)
                Spacer()
                Text(store.sessionText).font(.mono(15, .semibold)).foregroundStyle(t.accentText).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(t.accentRing).frame(height: 3)
                    Capsule().fill(t.accent).frame(width: geo.size.width * store.sessionPct / 100, height: 3)
                }
            }.frame(height: 3)
            HStack {
                Text("자동 잠금까지").font(.sans(11)).foregroundStyle(t.ink2)
                Spacer()
                Button { store.lock(); ui.onLock() } label: {
                    HStack(spacing: 5) {
                        Text("지금 잠그기").font(.sans(11, .semibold)).foregroundStyle(t.ink)
                        Text("⌘L").font(.sans(11)).foregroundStyle(t.ink3)
                    }
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.lineStrong, lineWidth: 1)))
                }.buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 10, trailing: 12))
        .background(RoundedRectangle(cornerRadius: 10).fill(t.accentSoft))
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                lucide("lock").font(.system(size: 14)).foregroundStyle(t.ink2)
                Text("잠김").font(.sans(13, .semibold)).foregroundStyle(t.ink)
            }
            Text("이름은 보이고, 값은 보호되어 있습니다.").font(.sans(11)).foregroundStyle(t.ink2).lineSpacing(2)
            Button { ui.sheet = .unlock(reason: "값을 보거나 복사하려면 마스터 비밀번호를 입력하세요.") } label: {
                HStack(spacing: 6) {
                    Text("잠금 해제").font(.sans(12, .semibold))
                    Text("⌘U").font(.sans(12)).opacity(0.7)
                }
                .foregroundStyle(t.accentInk).frame(maxWidth: .infinity).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(t.accent))
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 1)))
    }
}

/// A namespace row with hover state and a context menu.
private struct RowButton: View {
    @Environment(\.theme) private var t
    let active: Bool
    let ns: NamespaceData
    let label: String
    let onSelect: () -> Void
    let onRename: () -> Void
    let onUp: () -> Void
    let onDown: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            lucide("folder-lock").font(.system(size: 14)).foregroundStyle(active ? t.accent : t.ink3)
            Text(label)
                .font(.sans(13, active ? .semibold : .regular)).foregroundStyle(t.ink)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
            Text("\(ns.secrets.count)").font(.mono(11)).foregroundStyle(t.ink3)
            if active {
                Menu {
                    Button("이름 변경", action: onRename)
                    Button("위로 이동", action: onUp)
                    Button("아래로 이동", action: onDown)
                    Divider()
                    Button("삭제…", role: .destructive, action: onDelete)
                } label: {
                    lucide("ellipsis").font(.system(size: 14)).foregroundStyle(t.ink3)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 22)
            }
        }
        .padding(.leading, 10).padding(.trailing, 4).frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 7).fill(active ? t.surface : (hover ? t.hover : .clear)))
        .overlay(active ? RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.04), lineWidth: 1) : nil)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onSelect)
    }
}
