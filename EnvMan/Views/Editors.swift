import SwiftUI

/// Create or rename a namespace. Names need no session.
struct NamespaceEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: VaultStore
    var existing: NamespaceData?

    @State private var name: String = ""

    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "네임스페이스 이름 변경" : "새 네임스페이스")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)
            TextField("이름 (예: my-api / production)", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("취소") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button(isEditing ? "저장" : "만들기", action: save)
                    .buttonStyle(PrimaryButtonStyle(disabled: trimmed.isEmpty))
                    .disabled(trimmed.isEmpty)
                    .frame(width: 90)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(theme.window)
        .onAppear { name = existing?.name ?? "" }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func save() {
        guard !trimmed.isEmpty else { return }
        if let existing { store.renameNamespace(id: existing.id, to: trimmed) }
        else { store.addNamespace(name: trimmed) }
        dismiss()
    }
}

/// Add a new secret or edit an existing one. Editing a value needs a session.
struct SecretEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: VaultStore
    var namespaceID: UUID
    var existing: SecretData?

    @State private var key: String = ""
    @State private var value: String = ""
    @State private var valueLoaded = false
    @State private var error: String?

    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "시크릿 편집" : "새 시크릿")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "키")
                TextField("KEY_NAME", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "값")
                if store.isUnlocked {
                    TextEditor(text: $value)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(height: 96)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: theme.controlRadius)
                                .fill(theme.panel)
                                .overlay(RoundedRectangle(cornerRadius: theme.controlRadius).strokeBorder(theme.hairline))
                        )
                } else {
                    Text("값을 편집하려면 먼저 잠금을 해제하세요.")
                        .font(.system(size: 12)).foregroundStyle(theme.warning)
                }
            }

            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(theme.danger)
            }

            HStack {
                Spacer()
                Button("취소") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("저장", action: save)
                    .buttonStyle(PrimaryButtonStyle(disabled: !canSave))
                    .disabled(!canSave)
                    .frame(width: 90)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(theme.window)
        .onAppear(perform: load)
    }

    private var trimmedKey: String { key.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedKey.isEmpty && store.isUnlocked }

    private func load() {
        key = existing?.key ?? ""
        if let existing, store.isUnlocked, !valueLoaded {
            value = (try? store.reveal(existing)) ?? ""
            valueLoaded = true
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            if let existing, existing.key != trimmedKey {
                store.renameKey(namespaceID: namespaceID, secretID: existing.id, to: trimmedKey)
            }
            try store.upsertSecret(namespaceID: namespaceID, key: trimmedKey, value: value)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "저장에 실패했습니다."
        }
    }
}
