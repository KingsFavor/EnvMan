import SwiftUI
import AppKit

struct Sidebar: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    @State private var creating = false
    @State private var newText = ""
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @FocusState private var focusNew: Bool
    @State private var settingsHover = false
    @State private var lockHover = false
    @State private var unlockHover = false
    @State private var extendHover = false

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
                // Auto-saves on Enter or when a click lands outside the field.
                // An empty field rolls back to the original name (commitRename skips it).
                RenameField(text: $renameText,
                            onCommit: { commitRename(ns) },
                            onCancel: { renamingID = nil })
            } else {
                RowButton(active: active, ns: ns, label: label,
                          onSelect: { ui.selectNamespace(ns.id) },
                          onRename: { renamingID = ns.id; renameText = ns.path },
                          onUp: { store.moveNamespace(id: ns.id, by: -1) },
                          onDown: { store.moveNamespace(id: ns.id, by: 1) },
                          onSetColor: { store.setNamespaceColor(id: ns.id, hex: $0) },
                          onDuplicate: { if let newID = store.duplicateNamespace(id: ns.id) { ui.selectNamespace(newID) } },
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
                .padding(.horizontal, 8).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(settingsHover ? t.hover : .clear))
                .contentShape(Rectangle())
            }.buttonStyle(.plain).onHover { settingsHover = $0 }
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
            HStack(spacing: 6) {
                Text("자동 잠금까지").font(.sans(11)).foregroundStyle(t.ink2)
                Spacer()
                Button { store.touchSession() } label: {
                    HStack(spacing: 4) {
                        lucide("refresh-cw").font(.system(size: 10))
                        Text("연장").font(.sans(11, .semibold))
                    }
                    .foregroundStyle(t.accentText)
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(extendHover ? t.hover : t.surface).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.lineStrong, lineWidth: 1)))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).onHover { extendHover = $0 }.help("세션 시간을 다시 늘립니다")
                Button { store.lock(); ui.onLock() } label: {
                    Text("바로 잠그기").font(.sans(11, .semibold)).foregroundStyle(t.ink)
                        .padding(.horizontal, 8).frame(height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(lockHover ? t.hover : t.surface).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.lineStrong, lineWidth: 1)))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).onHover { lockHover = $0 }.help("지금 바로 잠급니다 (⌘L)")
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
            Text("키 이름은 보이고, 값은 보호되어 있습니다.").font(.sans(11)).foregroundStyle(t.ink2).lineSpacing(2)
            Button { ui.sheet = .unlock(reason: "값을 보거나 복사하려면 비밀번호를 입력하세요.") } label: {
                HStack(spacing: 6) {
                    Text("잠금 해제").font(.sans(12, .semibold))
                    Text("⌘U").font(.sans(12)).opacity(0.7)
                }
                .foregroundStyle(t.accentInk).frame(maxWidth: .infinity).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(t.accent).overlay(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(unlockHover ? 0.1 : 0))))
            }.buttonStyle(.plain).onHover { unlockHover = $0 }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 1)))
    }
}

/// The inline namespace rename field. Auto-focuses, commits on Enter, cancels on
/// Esc, and commits when a mouse click lands anywhere outside the field (macOS does
/// not resign a text field on an empty-area click, so a local event monitor is used).
private struct RenameField: View {
    @Environment(\.theme) private var t
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var focused: Bool
    @State private var frame: CGRect = .zero
    @State private var monitor: Any?

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain).font(.sans(13)).focused($focused)
            .padding(.horizontal, 10).frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7).fill(t.field)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.accent, lineWidth: 1))
            )
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { frame = g.frame(in: .global) }
                    .onChange(of: g.frame(in: .global)) { _, f in frame = f }
            })
            .onSubmit { onCommit() }
            .onExitCommand { onCancel() }
            .onAppear {
                DispatchQueue.main.async { focused = true }
                installMonitor()
            }
            .onDisappear { removeMonitor() }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let win = event.window ?? NSApp.keyWindow, let content = win.contentView else { return event }
            let p = event.locationInWindow
            // Convert AppKit (bottom-left) to SwiftUI .global (top-left) coordinates.
            let point = CGPoint(x: p.x, y: content.bounds.height - p.y)
            if !frame.insetBy(dx: -2, dy: -2).contains(point) {
                DispatchQueue.main.async { onCommit() }
            }
            return event
        }
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
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
    let onSetColor: (String?) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @State private var hover = false
    @State private var iconHover = false
    @State private var menuHover = false
    @State private var showColor = false

    private var folderColor: Color {
        if let hex = ns.colorHex { return Color(hex: hex) }
        return active ? t.accent : t.ink3
    }

    var body: some View {
        HStack(spacing: 6) {
            Button { showColor = true } label: {
                lucide("folder-lock").font(.system(size: 14)).foregroundStyle(folderColor)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(iconHover ? t.hover : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { iconHover = $0 }
            .help("폴더 색상")
            .popover(isPresented: $showColor, arrowEdge: .leading) {
                ColorPopover(current: ns.colorHex) { onSetColor($0); showColor = false }
                    .environment(\.theme, t)
            }

            Text(label)
                .font(.sans(13, active ? .semibold : .regular)).foregroundStyle(t.ink)
                .lineLimit(1).truncationMode(.tail)
                // simultaneousGesture so the row's single-click select fires
                // instantly instead of waiting to rule out a double-click.
                .simultaneousGesture(TapGesture(count: 2).onEnded { onRename() })
            Spacer(minLength: 0)
            Text("\(ns.secrets.count)").font(.mono(11)).foregroundStyle(t.ink3)
            if active {
                Menu {
                    Button("이름 변경", action: onRename)
                    Button("색상…") { showColor = true }
                    Button("복제", action: onDuplicate)
                    Divider()
                    Button("위로 이동", action: onUp)
                    Button("아래로 이동", action: onDown)
                    Divider()
                    Button("삭제…", role: .destructive, action: onDelete)
                } label: {
                    lucide("ellipsis").font(.system(size: 14)).foregroundStyle(menuHover ? t.ink : t.ink3)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(menuHover ? t.hover : .clear))
                        .contentShape(Rectangle())
                        .onHover { menuHover = $0 }
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 22)
            }
        }
        .padding(.leading, 8).padding(.trailing, 4).frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 7).fill(active ? t.surface : (hover ? t.hover : .clear)))
        .overlay(active ? RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.04), lineWidth: 1) : nil)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onSelect)
    }
}

/// A small folder-color picker: a default palette plus a custom color well.
private struct ColorPopover: View {
    @Environment(\.theme) private var t
    let current: String?
    let onPick: (String?) -> Void

    @State private var custom: Color = .accentColor

    private let cols = Array(repeating: GridItem(.fixed(26), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("폴더 색상").font(.sans(13, .semibold)).foregroundStyle(t.ink)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(NamespacePalette.colors, id: \.self) { hex in
                    Swatch(hex: hex, selected: current?.uppercased() == hex.uppercased()) { onPick(hex) }
                }
            }
            Divider()
            HStack(spacing: 10) {
                ColorPicker(selection: $custom, supportsOpacity: false) {
                    Text("사용자 지정").font(.sans(12)).foregroundStyle(t.ink2)
                }
                .onChange(of: custom) { _, newValue in
                    if let hex = newValue.toHexRGB() { onPick(hex) }
                }
                Spacer()
                Button { onPick(nil) } label: {
                    Text("기본값").font(.sans(12, .medium)).foregroundStyle(t.ink2)
                }.buttonStyle(.plain)
            }
        }
        .padding(16).frame(width: 232)
    }

}

/// A single color swatch with hover feedback.
private struct Swatch: View {
    let hex: String
    let selected: Bool
    let onPick: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onPick) {
            Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0).padding(1))
                .overlay(Circle().strokeBorder(selected ? Color(hex: hex) : .clear, lineWidth: selected ? 2 : 0))
                .overlay(Circle().strokeBorder(.white.opacity(hover && !selected ? 0.9 : 0), lineWidth: 2).padding(1))
                .scaleEffect(hover ? 1.12 : 1)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                .animation(.easeOut(duration: 0.12), value: hover)
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}
