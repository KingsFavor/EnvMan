import SwiftUI

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(UpdateChecker.self) private var updates

    @State private var showChangePassword = false

    var body: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("설정").font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textPrimary)
                Spacer()
                Button("닫기") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
            .padding(16)
            Divider().overlay(theme.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    group("세션") {
                        Picker("유지 시간", selection: $settings.sessionSeconds) {
                            ForEach(AppSettings.sessionPresets, id: \.seconds) { p in
                                Text(p.label).tag(p.seconds)
                            }
                        }
                        Toggle("화면 잠금이나 절전 시 자동 잠금", isOn: $settings.lockOnSleep)
                    }

                    group("클립보드") {
                        Picker("복사 후 자동 삭제", selection: $settings.clipboardClearSeconds) {
                            ForEach(AppSettings.clipboardPresets, id: \.seconds) { p in
                                Text(p.label).tag(p.seconds)
                            }
                        }
                    }

                    group("보안") {
                        Button("마스터 비밀번호 변경") { showChangePassword = true }
                            .buttonStyle(SecondaryButtonStyle())
                        Text("비밀번호를 잊으면 값은 복구할 수 없습니다.")
                            .font(.system(size: 11)).foregroundStyle(theme.textMuted)
                    }

                    group("정보") {
                        HStack {
                            Text("버전").font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(BuildInfo.version).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.textMuted)
                        }
                        if updates.updateAvailable {
                            Button("새 버전 \(updates.latestVersion ?? "") 보기") {
                                if let url = updates.releaseURL { NSWorkspace.shared.open(url) }
                            }.buttonStyle(SecondaryButtonStyle())
                        } else {
                            Button("업데이트 확인") { updates.checkForUpdatesInteractive() }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 420, height: 520)
        .background(theme.window)
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(store: store).provideTheme(theme.scheme)
        }
    }

    @ViewBuilder private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            content()
        }
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: VaultStore

    @State private var current = ""
    @State private var next = ""
    @State private var confirm = ""
    @State private var error: String?

    private var valid: Bool { !current.isEmpty && next.count >= 8 && next == confirm }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("마스터 비밀번호 변경").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)
            SecureField("현재 비밀번호", text: $current).textFieldStyle(.roundedBorder)
            SecureField("새 비밀번호 (8자 이상)", text: $next).textFieldStyle(.roundedBorder)
            SecureField("새 비밀번호 확인", text: $confirm).textFieldStyle(.roundedBorder)
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(theme.danger) }
            HStack {
                Spacer()
                Button("취소") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("변경", action: change)
                    .buttonStyle(PrimaryButtonStyle(disabled: !valid)).disabled(!valid).frame(width: 90)
            }
        }
        .padding(20).frame(width: 400).background(theme.window)
    }

    private func change() {
        do {
            try store.changeMasterPassword(current: current, new: next)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "변경에 실패했습니다."
        }
    }
}
