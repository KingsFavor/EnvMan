import SwiftUI
import UniformTypeIdentifiers

/// Export selected secrets (or the whole namespace) as an encrypted `.envman` file
/// protected by a share password, independent of the master password.
struct ExportSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: VaultStore
    var namespaceID: UUID
    var secretIDs: Set<UUID>?

    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?

    private var valid: Bool { password.count >= 6 && password == confirm }
    private var scope: String {
        if let ids = secretIDs { return "선택한 \(ids.count)개" }
        return "네임스페이스 전체"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("암호화 내보내기").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Text("\(scope)를 공유 암호로 암호화한 .envman 파일로 저장합니다. 받는 사람은 이 암호로 열고 자신의 비밀번호로 다시 암호화합니다.")
                .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("공유 암호 (6자 이상)", text: $password).textFieldStyle(.roundedBorder)
            SecureField("공유 암호 확인", text: $confirm).textFieldStyle(.roundedBorder)

            if let error { Text(error).font(.system(size: 11)).foregroundStyle(theme.danger) }

            HStack {
                Spacer()
                Button("취소") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("파일로 저장", action: exportFile)
                    .buttonStyle(PrimaryButtonStyle(disabled: !valid))
                    .disabled(!valid)
                    .frame(width: 110)
            }
        }
        .padding(20).frame(width: 430).background(theme.window)
    }

    private func exportFile() {
        do {
            let data = try store.exportBundle(namespaceID: namespaceID, secretIDs: secretIDs, sharePassword: password)
            let panel = NSSavePanel()
            let name = store.namespace(namespaceID)?.name.replacingOccurrences(of: "/", with: "-") ?? "export"
            panel.nameFieldStringValue = "\(name).\(ShareBundle.fileExtension)"
            if let type = UTType(filenameExtension: ShareBundle.fileExtension) {
                panel.allowedContentTypes = [type]
            }
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                try? data.write(to: url, options: .atomic)
                dismiss()
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "내보내기에 실패했습니다."
        }
    }
}

/// Import an encrypted `.envman` file: decrypt with the share password, then
/// re-encrypt into this vault with the master password (session required).
struct ImportSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: VaultStore
    var namespaceID: UUID

    @State private var fileData: Data?
    @State private var fileName = ""
    @State private var password = ""
    @State private var payload: SharePayload?
    @State private var targetNamespace: UUID
    @State private var conflict: VaultStore.ConflictPolicy = .keepBoth
    @State private var error: String?

    init(store: VaultStore, namespaceID: UUID) {
        self.store = store
        self.namespaceID = namespaceID
        _targetNamespace = State(initialValue: namespaceID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("암호화 파일 가져오기").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)

            HStack {
                Button("파일 선택", action: pickFile).buttonStyle(SecondaryButtonStyle())
                Text(fileName.isEmpty ? "선택된 파일 없음" : fileName)
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted).lineLimit(1)
            }

            if fileData != nil && payload == nil {
                SecureField("공유 암호", text: $password).textFieldStyle(.roundedBorder).onSubmit(decrypt)
                Button("복호화", action: decrypt).buttonStyle(SecondaryButtonStyle())
            }

            if let payload {
                VStack(alignment: .leading, spacing: 8) {
                    Text("원본 네임스페이스: \(payload.namespace), \(Formatting.count(payload.secrets.count))")
                        .font(.system(size: 12)).foregroundStyle(theme.textSecondary)

                    SectionLabel(text: "저장할 네임스페이스")
                    Picker("", selection: $targetNamespace) {
                        ForEach(store.vault?.namespaces ?? []) { ns in Text(ns.name).tag(ns.id) }
                    }.labelsHidden()

                    SectionLabel(text: "중복 키")
                    Picker("", selection: $conflict) {
                        Text("둘 다 유지").tag(VaultStore.ConflictPolicy.keepBoth)
                        Text("덮어쓰기").tag(VaultStore.ConflictPolicy.overwrite)
                        Text("건너뛰기").tag(VaultStore.ConflictPolicy.skip)
                    }.pickerStyle(.segmented)

                    if !store.isUnlocked {
                        Text("가져오려면 먼저 잠금을 해제하세요.")
                            .font(.system(size: 11)).foregroundStyle(theme.warning)
                    }
                }
            }

            if let error { Text(error).font(.system(size: 11)).foregroundStyle(theme.danger) }

            HStack {
                Spacer()
                Button("취소") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("가져오기", action: apply)
                    .buttonStyle(PrimaryButtonStyle(disabled: payload == nil || !store.isUnlocked))
                    .disabled(payload == nil || !store.isUnlocked)
                    .frame(width: 100)
            }
        }
        .padding(20).frame(width: 440).background(theme.window)
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        if let type = UTType(filenameExtension: ShareBundle.fileExtension) {
            panel.allowedContentTypes = [type]
        }
        panel.allowsOtherFileTypes = true
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            fileData = data
            fileName = url.lastPathComponent
            payload = nil
            error = nil
        }
    }

    private func decrypt() {
        guard let fileData else { return }
        do {
            payload = try store.previewImport(fileData: fileData, sharePassword: password)
            error = nil
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "복호화에 실패했습니다."
        }
    }

    private func apply() {
        guard let payload else { return }
        do {
            try store.applyImport(payload, into: targetNamespace, conflict: conflict)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "가져오기에 실패했습니다."
        }
    }
}
