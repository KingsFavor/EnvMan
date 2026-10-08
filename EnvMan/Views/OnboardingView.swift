import SwiftUI
import AppKit

struct OnboardingView: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store

    @State private var step = 0
    @State private var pw = ""
    @State private var pw2 = ""
    @State private var recovery = RecoveryKey.generate()
    @State private var saved = false
    @State private var error: String?

    private let labels = ["시작", "비밀번호", "복구 키", "보호 방식"]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: titleBarInset)
            VStack(spacing: 0) {
                stepper.padding(.top, 20).padding(.bottom, 44)
                Group {
                    switch step {
                    case 0: intro
                    case 1: createPassword
                    case 2: recoveryKey
                    default: protection
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .background(t.win)
    }

    // MARK: Stepper

    private var stepper: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(i == step ? t.accent : t.fill)
                            .overlay(Circle().strokeBorder(i == step ? .clear : t.lineStrong, lineWidth: 1))
                            .frame(width: 20, height: 20)
                        Text("\(i + 1)").font(.sans(11, .semibold)).foregroundStyle(i == step ? t.accentInk : t.ink3)
                    }
                    Text(labels[i]).font(.sans(12, i == step ? .semibold : .regular))
                        .foregroundStyle(i == step ? t.ink : t.ink3)
                    if i < 3 { Rectangle().fill(t.lineStrong).frame(width: 28, height: 1).padding(.horizontal, 4) }
                }
            }
        }
    }

    // MARK: Step 0 intro

    private var intro: some View {
        VStack(spacing: 0) {
            Image("BrandMark").renderingMode(.template).resizable().frame(width: 96, height: 96)
                .foregroundStyle(t.accent).padding(.bottom, 22)
            Text("EnvMan").font(.sans(28, .bold)).foregroundStyle(t.ink)
            Text("환경변수와 API 키를 이 Mac 안에 암호화해 보관하고, 필요할 때 바로 복사합니다.")
                .font(.sans(15)).foregroundStyle(t.ink2).multilineTextAlignment(.center)
                .lineSpacing(3).padding(.top, 8).frame(width: 420)

            VStack(spacing: 0) {
                introRow("hard-drive", "이 Mac에만 저장됩니다", "값은 암호화되어 디스크에 남고, 네트워크로 보내지 않습니다.", first: true)
                introRow("lock-keyhole", "이름은 열려 있고, 값은 잠겨 있습니다", "키 이름은 바로 보이고, 값은 비밀번호로만 열립니다.")
                introRow("clipboard-x", "복사한 값은 잠시 후 지워집니다", "클립보드에 오래 남지 않도록 자동으로 비웁니다.")
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.line, lineWidth: 1)))
            .frame(width: 460).padding(.top, 32)

            AccentButton(title: "시작하기", height: 36, hpad: 22, fontSize: 14) { step = 1 }
                .padding(.top, 28)
        }
        .frame(width: 460)
    }

    private func introRow(_ icon: String, _ title: String, _ desc: String, first: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            lucide(icon).font(.system(size: 18)).foregroundStyle(t.ink2).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.sans(13, .semibold)).foregroundStyle(t.ink)
                Text(desc).font(.sans(12)).foregroundStyle(t.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .overlay(alignment: .top) { if !first { Rectangle().fill(t.lineSoft).frame(height: 1) } }
    }

    // MARK: Step 1 create password

    private var strength: Int {
        var s = 0
        if pw.count >= 8 { s += 1 }
        if pw.count >= 12 { s += 1 }
        if pw.contains(where: \.isNumber) && pw.contains(where: \.isLetter) { s += 1 }
        if pw.contains(where: { !$0.isLetter && !$0.isNumber }) { s += 1 }
        return min(4, s)
    }
    private var strengthLabel: (String, Color) {
        switch strength {
        case 0, 1: return ("약함", t.danger)
        case 2: return ("보통", t.warn)
        default: return ("강함", t.accentText)
        }
    }
    private var pwValid: Bool { pw.count >= 8 && pw == pw2 }

    private var createPassword: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("마스터 비밀번호 만들기").font(.sans(22, .bold)).foregroundStyle(t.ink)
            Text("값을 암호화하는 데 쓰는 비밀번호입니다. 이 Mac 밖으로 나가지 않습니다.")
                .font(.sans(13)).foregroundStyle(t.ink2).padding(.top, 6)

            FieldLabel(text: "비밀번호", color: t.ink2).padding(.top, 26).padding(.bottom, 6)
            SecureField("12자 이상 권장", text: $pw).font(.mono(14)).frame(height: 36).fieldBG()

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(i < strength ? strengthLabel.1 : t.lineStrong).frame(height: 4)
                }
            }.padding(.top, 8)
            HStack {
                Text(pw.isEmpty ? "" : strengthLabel.0).font(.sans(12, .semibold)).foregroundStyle(strengthLabel.1)
                Spacer()
                Text("길고 다양할수록 안전합니다").font(.sans(12)).foregroundStyle(t.ink3)
            }.padding(.top, 6)

            FieldLabel(text: "비밀번호 확인", color: t.ink2).padding(.top, 18).padding(.bottom, 6)
            SecureField("한 번 더 입력", text: $pw2).font(.mono(14)).frame(height: 36).fieldBG()
            if !pw2.isEmpty && pw != pw2 {
                Text("비밀번호가 서로 다릅니다.").font(.sans(12)).foregroundStyle(t.danger).padding(.top, 6)
            }

            HStack(alignment: .top, spacing: 10) {
                lucide("shield-alert").font(.system(size: 16)).foregroundStyle(t.ink2).padding(.top, 1)
                Text("비밀번호를 잊으면 저장한 값은 되살릴 수 없습니다. 대신 다음 단계에서 금고를 다시 열 수 있는 복구 키를 드립니다.")
                    .font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(3)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(t.fill))
            .padding(.top, 22)

            HStack {
                GhostButton(title: "이전", height: 32) { step = 0 }
                Spacer()
                AccentButton(title: "다음", height: 32, hpad: 18, disabled: !pwValid) { if pwValid { step = 2 } }
            }.padding(.top, 28)
        }
        .frame(width: 420)
    }

    // MARK: Step 2 recovery key

    private var recoveryKey: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("복구 키 보관하기").font(.sans(22, .bold)).foregroundStyle(t.ink)
            Text("비밀번호를 잊었을 때 금고를 다시 여는 유일한 방법입니다. 이 키는 지금 한 번만 표시됩니다.")
                .font(.sans(13)).foregroundStyle(t.ink2).padding(.top, 6)

            VStack(spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 10) {
                    ForEach(RecoveryKey.grid(recovery), id: \.self) { g in
                        Text(g).font(.mono(19, .semibold)).kerning(1.5).foregroundStyle(t.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 7).fill(t.fill))
                    }
                }
                HStack(spacing: 8) {
                    GhostButton(title: "복사", icon: "copy", height: 28, hpad: 10, fontSize: 12) {
                        store.copyToClipboard(recovery, title: "복구 키를 복사했습니다")
                    }
                    GhostButton(title: "파일로 저장", icon: "download", height: 28, hpad: 10, fontSize: 12) { saveRecovery() }
                    GhostButton(title: "인쇄", icon: "printer", height: 28, hpad: 10, fontSize: 12) { saveRecovery() }
                }
            }
            .padding(EdgeInsets(top: 22, leading: 20, bottom: 16, trailing: 20))
            .background(RoundedRectangle(cornerRadius: 12).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.lineStrong, lineWidth: 1)))
            .padding(.top, 24)

            Text("비밀번호 관리자나 종이에 적어 이 Mac이 아닌 곳에 두세요. EnvMan은 복구 키를 저장하지 않습니다.")
                .font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(3).padding(.top, 14)

            Button { saved.toggle() } label: {
                HStack(spacing: 10) {
                    CheckBox(on: saved, size: 16)
                    Text("복구 키를 안전한 곳에 보관했습니다").font(.sans(13, .medium)).foregroundStyle(t.ink)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).padding(.top, 20)

            HStack {
                GhostButton(title: "이전", height: 32) { step = 1 }
                Spacer()
                AccentButton(title: "다음", height: 32, hpad: 18, disabled: !saved) { if saved { step = 3 } }
            }.padding(.top, 28)
        }
        .frame(width: 460)
    }

    // MARK: Step 3 protection

    private var protection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("이렇게 보호됩니다").font(.sans(22, .bold)).foregroundStyle(t.ink)
            Text("자주 여는 앱이라서, 찾는 일은 비밀번호 없이 하고 값을 꺼낼 때만 잠금을 엽니다.")
                .font(.sans(13)).foregroundStyle(t.ink2).padding(.top, 6)

            HStack(spacing: 12) {
                protectionCard(icon: "eye", title: "비밀번호 없이 보이는 것", items: ["네임스페이스 이름", "키 이름 (예: DATABASE_URL)", "메모"], accent: false)
                protectionCard(icon: "lock", title: "비밀번호가 있어야 하는 것", items: ["값 보기", "값 복사", "내보내기와 가져오기"], accent: true)
            }.padding(.top, 24)

            Text("잠금을 해제하면 15분 동안 열려 있고, 그 뒤 자동으로 잠깁니다. 시간은 설정에서 바꿀 수 있습니다.")
                .font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(3).padding(.top, 16)

            if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 10) }

            HStack {
                GhostButton(title: "이전", height: 32) { step = 2 }
                Spacer()
                AccentButton(title: "EnvMan 시작하기", height: 32, hpad: 18) { finish() }
            }.padding(.top, 28)
        }
        .frame(width: 540)
    }

    private func protectionCard(icon: String, title: String, items: [String], accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                lucide(icon).font(.system(size: 15)).foregroundStyle(accent ? t.accentText : t.ink2)
                Text(title).font(.sans(13, .semibold)).foregroundStyle(accent ? t.accentText : t.ink)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { Text($0).font(.sans(13)).foregroundStyle(t.ink2) }
            }.padding(.top, 14)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(accent ? t.accentSoft : t.surface).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent ? t.accent : t.line, lineWidth: 1)))
    }

    // MARK: Actions

    private func finish() {
        do { try store.createVault(masterPassword: pw, recoveryKey: recovery) }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "볼트 생성에 실패했습니다." }
    }

    private func saveRecovery() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "EnvMan-복구키.txt"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            try? "EnvMan 복구 키\n\n\(recovery)\n\n안전한 곳에 보관하세요. 이 키로 비밀번호를 재설정할 수 있습니다.".write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
