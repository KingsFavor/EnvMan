import SwiftUI

struct UnlockSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store

    let reason: String
    var startInRecovery: Bool = false

    @State private var recoveryMode = false
    @State private var pw = ""
    @State private var error: String?
    @State private var recKey = ""
    @State private var recPw = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 12).fill(t.fill).frame(width: 44, height: 44)
                .overlay(lucide("lock-keyhole").font(.system(size: 20)).foregroundStyle(t.ink))
                .padding(.bottom, 14)

            if recoveryMode { recoveryContent } else { passwordContent }
        }
        .padding(EdgeInsets(top: 26, leading: 28, bottom: 22, trailing: 28))
        .frame(width: 440)
        .background(t.surface)
        .onAppear { recoveryMode = startInRecovery; DispatchQueue.main.async { focused = true } }
    }

    private var passwordContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("금고 잠금 해제").font(.sans(17, .bold)).foregroundStyle(t.ink)
            Text(reason).font(.sans(12.5)).foregroundStyle(t.ink2).lineSpacing(2).padding(.top, 5)

            SecureField("마스터 비밀번호", text: $pw).font(.mono(14)).frame(height: 36).fieldBG(focused)
                .focused($focused).padding(.top, 18).onSubmit(submit)

            if let error {
                HStack(spacing: 6) {
                    lucide("circle-alert").font(.system(size: 13))
                    Text(error).font(.sans(12))
                }.foregroundStyle(t.danger).padding(.top, 8)
            }

            HStack {
                Button("비밀번호를 잊었나요?") { recoveryMode = true; error = nil }
                    .buttonStyle(.plain).font(.sans(12)).foregroundStyle(t.accentText)
                Spacer()
                HStack(spacing: 8) {
                    GhostButton(title: "취소") { dismiss() }
                    AccentButton(title: "잠금 해제", disabled: pw.isEmpty, action: submit)
                }
            }.padding(.top, 22)
        }
    }

    private var recoveryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("복구 키로 재설정").font(.sans(17, .bold)).foregroundStyle(t.ink)
            Text("온보딩에서 받은 복구 키를 입력하고 새 비밀번호를 정하세요. 재설정하면 새 복구 키가 발급되고 이전 키는 무효가 됩니다.")
                .font(.sans(12.5)).foregroundStyle(t.ink2).lineSpacing(2).padding(.top, 5)

            FieldLabel(text: "복구 키", color: t.ink2).padding(.top, 18).padding(.bottom, 6)
            TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $recKey).font(.mono(13)).kerning(1).frame(height: 34).fieldBG()

            FieldLabel(text: "새 마스터 비밀번호", color: t.ink2).padding(.top, 14).padding(.bottom, 6)
            SecureField("", text: $recPw).font(.mono(13)).frame(height: 34).fieldBG()

            if let error {
                HStack(spacing: 6) { lucide("circle-alert").font(.system(size: 13)); Text(error).font(.sans(12)) }
                    .foregroundStyle(t.danger).padding(.top, 8)
            }

            HStack {
                GhostButton(title: "돌아가기") { recoveryMode = false; error = nil }
                Spacer()
                AccentButton(title: "재설정하고 열기", disabled: recKey.isEmpty || recPw.count < 8, action: submitRecovery)
            }.padding(.top, 22)
        }
    }

    private func submit() {
        guard !pw.isEmpty else { return }
        do { try store.unlock(masterPassword: pw); dismiss() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "해제에 실패했습니다."; pw = "" }
    }

    private func submitRecovery() {
        do {
            _ = try store.resetWithRecoveryKey(recKey, newPassword: recPw)
            dismiss()
            store.showToast(.init(icon: "circle-check", title: "비밀번호를 재설정했습니다", sub: "설정에서 새 복구 키를 확인하세요."))
        } catch {
            self.error = "복구 키가 올바르지 않습니다."
        }
    }
}
