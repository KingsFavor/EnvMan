import SwiftUI

struct SecretRow: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    let namespaceID: UUID
    let secret: SecretData

    @State private var hover = false
    @State private var eyeHover = false
    @State private var menuHover = false
    @State private var memoEditing = false
    @State private var memoText = ""
    @FocusState private var memoFocused: Bool

    private var selected: Bool { ui.selected.contains(secret.id) }
    private var revealed: Bool { ui.revealed.contains(secret.id) }
    private var revealedValue: String { ui.revealedValues[secret.id] ?? "" }
    private var multiline: Bool { revealed && revealedValue.contains("\n") }

    var body: some View {
        HStack(spacing: 12) {
            Button { toggleSelect() } label: { CheckBox(on: selected) }
                .buttonStyle(.plain).frame(width: 20, alignment: .leading)

            // Double-click to copy lives on the content area only, so it never
            // competes with the checkbox or the action buttons for clicks.
            HStack(spacing: 12) {
                keyColumn.frame(maxWidth: .infinity, alignment: .leading)
                valueColumn.frame(maxWidth: .infinity, alignment: .leading)
                Text(Formatting.ago(secret.updated)).font(.sans(11.5)).foregroundStyle(t.ink3).frame(width: 56, alignment: .leading)
            }
            .contentShape(Rectangle())
            // simultaneousGesture (not onTapGesture) so it never makes the
            // checkbox or action buttons wait to disambiguate a single click.
            .simultaneousGesture(TapGesture(count: 2).onEnded { copyValue() })

            actions.frame(width: 150, alignment: .trailing)
        }
        .padding(.leading, 20).padding(.trailing, 16)
        .frame(minHeight: 48)
        .background(hover ? t.hover : .clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }

    private var keyColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(secret.key).font(.mono(12.5, .semibold)).foregroundStyle(t.ink).lineLimit(1).truncationMode(.tail)
            if memoEditing {
                TextField("메모 (암호화되지 않음, 민감한 값을 포함하지 마세요)", text: $memoText)
                    .textFieldStyle(.plain).font(.sans(11.5)).focused($memoFocused)
                    .padding(.horizontal, 6).frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(t.field).overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(t.accent, lineWidth: 1)))
                    .onSubmit { commitMemo() }
                    .onExitCommand { memoEditing = false }
            } else if !secret.memo.isEmpty {
                Text(secret.memo).font(.sans(11.5)).foregroundStyle(t.ink3).lineLimit(1)
                    .onTapGesture { startMemo() }
            } else {
                Button { startMemo() } label: {
                    HStack(spacing: 4) {
                        lucide("plus").font(.system(size: 11))
                        Text("메모 추가").font(.sans(11.5))
                    }.foregroundStyle(t.ink3)
                }.buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private var valueColumn: some View {
        HStack(spacing: 6) {
            if !store.isUnlocked {
                lucide("lock").font(.system(size: 11)).foregroundStyle(t.ink3)
            }
            Text(displayValue)
                .font(.mono(12))
                .foregroundStyle(revealed ? t.ink : t.ink3)
                .kerning(revealed ? 0 : 1)
                .lineLimit(1).truncationMode(.tail)
            if multiline {
                Text("\(revealedValue.components(separatedBy: "\n").count)줄")
                    .font(.sans(10.5)).foregroundStyle(t.ink2)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(t.fill))
            }
        }
    }

    private var displayValue: String {
        if revealed { return revealedValue.replacingOccurrences(of: "\n", with: " ") }
        return String(repeating: "•", count: 10)
    }

    private var actions: some View {
        HStack(spacing: 2) {
            Button { toggleReveal() } label: {
                lucide(revealed ? "eye-off" : "eye").font(.system(size: 14)).foregroundStyle(eyeHover ? t.ink : t.ink3)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(eyeHover ? t.hover : .clear))
            }
            .buttonStyle(.plain).opacity(hover || revealed ? 1 : 0)
            .onHover { eyeHover = $0 }
            .help(revealed ? "값 가리기" : "값 보기")

            CopyMiniButton { copyValue() }

            Menu {
                Button("편집…") { requireUnlock { ui.sheet = .edit(secret.id) } }
                Button(secret.memo.isEmpty ? "메모 추가" : "메모 편집") { startMemo() }
                Button("키 이름 복사") { store.copyToClipboard(secret.key, title: "키 이름을 복사했습니다") }
                Divider()
                Button("삭제", role: .destructive) { store.deleteSecret(namespaceID: namespaceID, secretID: secret.id) }
            } label: {
                lucide("ellipsis").font(.system(size: 14)).foregroundStyle(menuHover ? t.ink : t.ink3).frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(menuHover ? t.hover : .clear))
                    .contentShape(Rectangle())
                    .onHover { menuHover = $0 }
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
        }
    }

    // MARK: Actions

    private func toggleSelect() {
        if selected { ui.selected.remove(secret.id) } else { ui.selected.insert(secret.id) }
    }

    private func toggleReveal() {
        if revealed { ui.revealed.remove(secret.id); ui.revealedValues[secret.id] = nil; return }
        requireUnlock {
            if let v = try? store.reveal(secret) { ui.revealedValues[secret.id] = v; ui.revealed.insert(secret.id) }
        }
    }

    private func copyValue() {
        requireUnlock {
            guard let v = try? store.reveal(secret) else { return }
            store.copyToClipboard(v, title: "\(secret.key) 복사됨")
        }
    }

    private func startMemo() { memoText = secret.memo; memoEditing = true; DispatchQueue.main.async { memoFocused = true } }
    private func commitMemo() { store.setMemo(namespaceID: namespaceID, secretID: secret.id, memo: memoText); memoEditing = false }

    private func requireUnlock(_ action: @escaping () -> Void) {
        if store.isUnlocked { action() } else { ui.sheet = .unlock(reason: "값을 보거나 복사하려면 비밀번호를 입력하세요.") }
    }
}

private struct CopyMiniButton: View {
    @Environment(\.theme) private var t
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            lucide("copy").font(.system(size: 14))
                .foregroundStyle(hover ? t.accent : t.ink2)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(hover ? t.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hover = $0 }
        .help("값 복사")
    }
}
