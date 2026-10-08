import SwiftUI

struct AddSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    var paste: Bool = false
    var editing: UUID? = nil

    private enum Tab { case one, paste }
    @State private var tab: Tab = .one
    @State private var key = ""
    @State private var value = ""
    @State private var memo = ""
    @State private var pasteText = ""
    @State private var policy: VaultStore.ConflictPolicy = .overwrite
    @State private var error: String?
    @FocusState private var keyFocused: Bool

    private var namespaceID: UUID { ui.selectedNamespace ?? UUID() }
    private var ns: NamespaceData? { store.namespace(namespaceID) }
    private var isEditing: Bool { editing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isEditing ? "시크릿 편집" : "새 시크릿").font(.sans(17, .bold)).foregroundStyle(t.ink)
                Spacer()
                Text(ns?.path ?? "").font(.mono(12)).foregroundStyle(t.ink3)
            }

            if !isEditing {
                Seg(options: [(Tab.one, "한 개씩"), (Tab.paste, ".env 붙여넣기")], selection: $tab).padding(.top, 16)
            }

            if tab == .one || isEditing { oneForm } else { pasteForm }

            if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 10) }

            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                AccentButton(title: submitLabel, disabled: !canSubmit, action: submit)
            }.padding(.top, 22)
        }
        .padding(EdgeInsets(top: 22, leading: 24, bottom: 20, trailing: 24))
        .frame(width: 460)
        .background(t.surface)
        .onAppear { setup() }
    }

    // MARK: One

    private var dupExisting: SecretData? {
        guard !isEditing else { return nil }
        return ns?.secrets.first { $0.key == key && !key.isEmpty }
    }

    private var oneForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldLabel(text: "키 이름", color: t.ink2).padding(.top, 18).padding(.bottom, 6)
            TextField("DATABASE_URL", text: $key).font(.mono(13)).frame(height: 34).fieldBG(keyFocused).focused($keyFocused)
                .onChange(of: key) { _, v in key = VaultStore.normalizeKey(v) }
            Text("대문자, 숫자, 밑줄만 씁니다. 입력하면 자동으로 바꿔 드립니다.").font(.sans(11)).foregroundStyle(t.ink3).padding(.top, 5)

            if let dup = dupExisting {
                HStack(alignment: .top, spacing: 10) {
                    lucide("triangle-alert").font(.system(size: 14)).foregroundStyle(t.warn).padding(.top, 1)
                    (Text("이 네임스페이스에 이미 있는 키입니다. ").font(.sans(12).weight(.semibold)).foregroundColor(t.warn)
                     + Text("저장하면 기존 값(\(Formatting.ago(dup.updated)) 수정)을 덮어씁니다.").font(.sans(12)).foregroundColor(t.ink2))
                        .lineSpacing(2)
                }
                .padding(.horizontal, 12).padding(.vertical, 10).padding(.top, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(t.warnSoft).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.warnLine, lineWidth: 1)))
            }

            FieldLabel(text: "값", color: t.ink2).padding(.top, 16).padding(.bottom, 6)
            TextEditorField(text: $value, placeholder: "여러 줄 값도 그대로 붙여넣을 수 있습니다", height: 92, mono: true)

            FieldLabel(text: "메모 (선택)", color: t.ink2).padding(.top, 16).padding(.bottom, 6)
            TextField("예: 결제, 라이브 키", text: $memo).font(.sans(13)).frame(height: 32).fieldBG()
            Text("메모는 암호화되지 않고 잠긴 상태에서도 보입니다. 값을 적지 마세요.").font(.sans(11)).foregroundStyle(t.ink3).padding(.top, 5)
        }
    }

    // MARK: Paste

    private var parsed: [VaultStore.ParsedLine] { store.parseDotenv(pasteText, namespaceID: namespaceID) }
    private var dupCount: Int { parsed.filter { $0.isDup }.count }

    private var pasteForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditorField(text: $pasteText, placeholder: "DATABASE_URL=postgres://…\nexport REDIS_URL=redis://…\n# 주석은 건너뜁니다", height: 130, mono: true).padding(.top, 16)

            if !parsed.isEmpty {
                HStack {
                    Text("\(parsed.count)개 중 신규 \(parsed.count - dupCount)개, 중복 \(dupCount)개")
                        .font(.sans(12)).foregroundStyle(t.ink2)
                    Spacer()
                    if dupCount > 0 {
                        Seg(options: [(VaultStore.ConflictPolicy.overwrite, "덮어쓰기"), (.skip, "건너뛰기"), (.keepBoth, "둘 다")], selection: $policy, height: 22, fontSize: 11.5).fixedSize()
                    }
                }.padding(.top, 14)

                VStack(spacing: 0) {
                    ForEach(parsed.prefix(50)) { p in
                        HStack(spacing: 10) {
                            Text(p.key).font(.mono(12, .semibold)).foregroundStyle(t.ink).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                            badge(for: p)
                        }
                        .padding(.horizontal, 12).frame(height: 30)
                        .overlay(alignment: .bottom) { Rectangle().fill(t.lineSoft).frame(height: 1) }
                    }
                }
                .frame(maxHeight: 150)
                .background(RoundedRectangle(cornerRadius: 9).strokeBorder(t.line, lineWidth: 1))
                .padding(.top, 8)
            }
        }
    }

    private func badge(for p: VaultStore.ParsedLine) -> some View {
        let (text, bg, fg): (String, Color, Color)
        if !p.isDup { (text, bg, fg) = ("신규", t.accentSoft, t.accentText) }
        else {
            switch policy {
            case .overwrite: (text, bg, fg) = ("덮어씀", t.warnSoft, t.warn)
            case .skip: (text, bg, fg) = ("건너뜀", t.fill, t.ink3)
            case .keepBoth: (text, bg, fg) = ("새 이름", t.accentSoft, t.accentText)
            }
        }
        return Text(text).font(.sans(11, .semibold)).foregroundStyle(fg)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(bg))
    }

    // MARK: Logic

    private var submitLabel: String {
        if isEditing { return "저장" }
        if tab == .paste { return parsed.isEmpty ? "가져오기" : "\(parsed.filter { !($0.isDup && policy == .skip) }.count)개 가져오기" }
        return "추가"
    }
    private var canSubmit: Bool {
        if tab == .paste && !isEditing { return !parsed.isEmpty }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func setup() {
        if paste { tab = .paste }
        if let id = editing, let s = ns?.secrets.first(where: { $0.id == id }) {
            key = s.key; memo = s.memo
            value = (try? store.reveal(s)) ?? ""
        } else {
            DispatchQueue.main.async { keyFocused = true }
        }
    }

    private func submit() {
        do {
            if let id = editing {
                try store.editSecret(namespaceID: namespaceID, secretID: id, newKey: key, newValue: value, newMemo: memo)
            } else if tab == .paste {
                try store.applyParsed(parsed, namespaceID: namespaceID, policy: policy)
            } else {
                try store.upsert(namespaceID: namespaceID, key: key, value: value, memo: memo)
            }
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "저장에 실패했습니다."
        }
    }
}

/// A bordered multiline text editor with a placeholder.
struct TextEditorField: View {
    @Environment(\.theme) private var t
    @Binding var text: String
    var placeholder: String
    var height: CGFloat = 92
    var mono: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder).font(mono ? .mono(12.5) : .sans(13)).foregroundStyle(t.ink3)
                    .padding(.horizontal, 12).padding(.top, 9).allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(mono ? .mono(12.5) : .sans(13)).scrollContentBackground(.hidden)
                .padding(.horizontal, 8).padding(.vertical, 2)
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 8).fill(t.field).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.lineStrong, lineWidth: 1)))
    }
}
