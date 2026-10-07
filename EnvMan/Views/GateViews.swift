import SwiftUI

/// First run: create the master password that protects all values.
struct OnboardingView: View {
    @Environment(\.theme) private var theme
    var store: VaultStore
    var compact: Bool = false

    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?

    private var valid: Bool { password.count >= 8 && password == confirm }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("마스터 비밀번호 만들기")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("값을 암호화할 비밀번호입니다. 잊으면 복구할 수 없으니 안전하게 보관하세요.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecureField("비밀번호 (8자 이상)", text: $password)
                .textFieldStyle(.roundedBorder)
            SecureField("비밀번호 확인", text: $confirm)
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)

            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(theme.danger)
            }
            if !password.isEmpty && password.count < 8 {
                Text("8자 이상을 권장합니다.").font(.system(size: 11)).foregroundStyle(theme.warning)
            }

            Button("볼트 만들기", action: create)
                .buttonStyle(PrimaryButtonStyle(disabled: !valid))
                .disabled(!valid)
        }
        .padding(compact ? 14 : 24)
        .frame(maxWidth: compact ? .infinity : 420)
    }

    private func create() {
        guard valid else { return }
        do { try store.createVault(masterPassword: password); error = nil }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "볼트 생성에 실패했습니다." }
    }
}

/// Unlock an existing vault to start a session.
struct UnlockView: View {
    @Environment(\.theme) private var theme
    var store: VaultStore
    var compact: Bool = false

    @State private var password = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").foregroundStyle(theme.locked)
                Text("잠금 해제")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            Text("값을 보거나 복사하려면 마스터 비밀번호를 입력하세요. 목록은 잠금 상태에서도 볼 수 있습니다.")
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("마스터 비밀번호", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(unlock)

            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(theme.danger)
            }

            Button("해제", action: unlock)
                .buttonStyle(PrimaryButtonStyle(disabled: password.isEmpty))
                .disabled(password.isEmpty)
        }
        .padding(compact ? 14 : 24)
        .frame(maxWidth: compact ? .infinity : 420)
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        do {
            try store.unlock(masterPassword: password)
            password = ""
            error = nil
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "해제에 실패했습니다."
            password = ""
        }
    }
}
