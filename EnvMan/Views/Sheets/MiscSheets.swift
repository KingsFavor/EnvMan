import SwiftUI

// MARK: Delete namespace

struct DeleteNamespaceSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui
    let namespaceID: UUID

    private var ns: NamespaceData? { store.namespace(namespaceID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 12).fill(t.dangerSoft).frame(width: 44, height: 44)
                .overlay(lucide("trash-2").font(.system(size: 20)).foregroundStyle(t.danger)).padding(.bottom, 14)
            Text("‘\(ns?.path ?? "")’ 삭제").font(.sans(17, .bold)).foregroundStyle(t.ink)
            (Text("이 네임스페이스와 안에 있는 ").font(.sans(12.5)).foregroundColor(t.ink2)
             + Text("시크릿 \(ns?.secrets.count ?? 0)개").font(.sans(12.5).weight(.bold)).foregroundColor(t.ink)
             + Text("가 함께 삭제됩니다. 되돌릴 수 없습니다.").font(.sans(12.5)).foregroundColor(t.ink2))
                .lineSpacing(3).padding(.top, 6)
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                Button {
                    store.deleteNamespace(id: namespaceID)
                    if ui.selectedNamespace == namespaceID { ui.selectNamespace(store.vault?.namespaces.first?.id) }
                    dismiss()
                } label: {
                    Text("삭제").font(.sans(13, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7).fill(t.danger))
                }.buttonStyle(.plain)
            }.padding(.top, 24)
        }
        .padding(EdgeInsets(top: 26, leading: 28, bottom: 22, trailing: 28))
        .frame(width: 440).background(t.surface)
    }
}

// MARK: Settings

struct SettingsSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(UpdateChecker.self) private var updates
    @Environment(UIState.self) private var ui

    @State private var showChange = false
    @State private var showReissue = false
    @State private var showReset = false
    @State private var showManual = false
    @State private var manualTopic: ManualTopic? = nil

    var body: some View {
        @Bindable var settings = settings
        return VStack(spacing: 0) {
            HStack {
                Text("설정").font(.sans(17, .bold)).foregroundStyle(t.ink)
                Spacer()
                AccentButton(title: "완료", height: 28, hpad: 14, fontSize: 12.5) { dismiss() }
            }
            .padding(.horizontal, 24).padding(.vertical, 18)
            .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("모양") {
                        settingRow("외형", "시스템 설정을 따르거나 라이트, 다크 모드로 고정합니다.") {
                            Seg(options: Appearance.allCases.map { ($0, $0.label) }, selection: $settings.appearance, height: 24, fontSize: 12).fixedSize()
                        }
                    }
                    section("세션과 클립보드") {
                        settingRow("세션 유지 시간", "잠금 해제 후 이 시간이 지나면 자동으로 다시 잠깁니다.") {
                            Seg(options: AppSettings.sessionPresets.map { ($0.seconds, $0.label) }, selection: $settings.sessionSeconds, height: 24, fontSize: 12).fixedSize()
                        }
                        divider
                        settingRow("클립보드 자동 삭제", "복사한 값을 이 시간 뒤에 클립보드에서 지웁니다.") {
                            Seg(options: AppSettings.clipPresets.map { ($0.seconds, $0.label) }, selection: $settings.clipboardClearSeconds, height: 24, fontSize: 12).fixedSize()
                        }
                    }
                    section("자동 잠금") {
                        toggleRow("화면이 잠기면 잠그기", $settings.lockOnScreenLock, first: true)
                        toggleRow("Mac이 절전에 들어가면 잠그기", $settings.lockOnSleep)
                        toggleRow("다른 앱으로 전환하면 잠그기", $settings.lockOnResign)
                        toggleRow("창을 닫으면 잠그기", $settings.lockOnWindowClose)
                    }
                    section("비밀번호와 복구") {
                        settingRow("비밀번호", "비밀번호를 잊으면 복구 키를 사용해야만 복구할 수 있습니다.") {
                            GhostButton(title: "변경…", height: 26, hpad: 10, fontSize: 12) { showChange = true }
                        }
                        divider
                        settingRow("복구 키", "새로 발급하면 이전 키는 바로 무효가 됩니다.") {
                            GhostButton(title: "재발급…", height: 26, hpad: 10, fontSize: 12) { showReissue = true }
                        }
                    }
                    section("데이터") {
                        settingRow("모두 내보내기", "네임스페이스 구성과 모든 시크릿을 하나의 암호화 파일로 내보냅니다. 다른 기기에서 그대로 가져올 수 있습니다.") {
                            GhostButton(title: "내보내기…", height: 26, hpad: 10, fontSize: 12) {
                                startData { ui.sheet = .exportAll }
                            }
                        }
                        divider
                        settingRow("모두 가져오기", "다른 곳에서 내보낸 전체 데이터 파일을 여기로 가져옵니다.") {
                            GhostButton(title: "가져오기…", height: 26, hpad: 10, fontSize: 12) {
                                startData { ui.sheet = .importAll }
                            }
                        }
                    }
                    section("도움말") {
                        settingRow("매뉴얼", "기능별 사용법을 그림과 함께 안내합니다.") {
                            GhostButton(title: "열기…", height: 26, hpad: 10, fontSize: 12) { manualTopic = nil; showManual = true }
                        }
                        divider
                        settingRow("터미널 히스토리 삭제 방법", "복사한 명령이 셸 기록에 남았을 때 지우는 방법입니다.") {
                            GhostButton(title: "보기…", height: 26, hpad: 10, fontSize: 12) { manualTopic = .terminalHistory; showManual = true }
                        }
                    }
                    section("앱 정보") {
                        settingRow("버전", updateStatusText) {
                            if updates.updateAvailable {
                                GhostButton(title: "릴리즈 보기", height: 26, hpad: 10, fontSize: 12) { updates.openReleasePage() }
                            } else {
                                GhostButton(title: "업데이트 확인", height: 26, hpad: 10, fontSize: 12) { updates.checkForUpdatesInteractive() }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        FieldLabel(text: "위험", color: t.danger)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("모든 데이터 초기화").font(.sans(13, .medium)).foregroundStyle(t.ink)
                                Text("비밀번호와 모든 값을 지웁니다. 복구 키로도 되돌릴 수 없습니다.").font(.sans(11.5)).foregroundStyle(t.ink3)
                            }
                            Spacer()
                            GhostButton(title: "초기화…", height: 26, hpad: 10, fontSize: 12, danger: true) { showReset = true }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(t.dangerSoft, lineWidth: 1))
                    }
                }
                .padding(EdgeInsets(top: 20, leading: 24, bottom: 24, trailing: 24))
            }
        }
        .frame(width: 460, height: 560).background(t.surface)
        .sheet(isPresented: $showChange) { ChangePasswordSheet().environment(\.theme, t) }
        .sheet(isPresented: $showReissue) { ReissueRecoverySheet().environment(\.theme, t) }
        .sheet(isPresented: $showReset) { ResetConfirmSheet(onDone: { dismiss() }).environment(\.theme, t) }
        .sheet(isPresented: $showManual) { ManualSheet(initial: manualTopic).environment(\.theme, t) }
    }

    private var updateStatusText: String {
        if updates.isChecking { return "업데이트를 확인하는 중입니다…" }
        if updates.updateAvailable, let v = updates.latestVersion { return "새 버전 \(v)을(를) 사용할 수 있습니다. 현재 \(BuildInfo.version)." }
        if updates.upToDateNotice { return "최신 버전입니다. 현재 \(BuildInfo.version)." }
        return "현재 \(BuildInfo.version)을(를) 사용 중입니다."
    }

    /// Full export and import both need the vault open to (de)crypt values. When
    /// locked, swap Settings for the unlock sheet and run the action once unlocked.
    private func startData(_ action: @escaping () -> Void) {
        if store.isUnlocked { action() }
        else { ui.requireUnlock(reason: "데이터를 내보내거나 가져오려면 비밀번호를 입력하세요.", then: action) }
    }

    private var divider: some View { Rectangle().fill(t.lineSoft).frame(height: 1) }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: title)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 1))
        }
    }

    private func settingRow<C: View>(_ title: String, _ sub: String, @ViewBuilder _ trailing: () -> C) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.sans(13, .medium)).foregroundStyle(t.ink)
                Text(sub).font(.sans(11.5)).foregroundStyle(t.ink3)
            }
            Spacer()
            trailing()
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>, first: Bool = false) -> some View {
        Button { binding.wrappedValue.toggle() } label: {
            HStack {
                Text(title).font(.sans(13)).foregroundStyle(t.ink)
                Spacer()
                Switch(on: binding.wrappedValue)
            }
            .padding(.horizontal, 14).padding(.vertical, 11).contentShape(Rectangle())
            .overlay(alignment: .top) { if !first { Rectangle().fill(t.lineSoft).frame(height: 1) } }
        }.buttonStyle(.plain)
    }
}

// MARK: Change password

struct ChangePasswordSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @State private var current = ""
    @State private var next = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("비밀번호 변경").font(.sans(17, .bold)).foregroundStyle(t.ink)
            FieldLabel(text: "현재 비밀번호", color: t.ink2).padding(.top, 18).padding(.bottom, 6)
            SecureField("", text: $current).font(.mono(13)).frame(height: 34).fieldBG()
            FieldLabel(text: "새 비밀번호 (8자 이상)", color: t.ink2).padding(.top, 14).padding(.bottom, 6)
            SecureField("", text: $next).font(.mono(13)).frame(height: 34).fieldBG()
            if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 8) }
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                AccentButton(title: "변경", disabled: current.isEmpty || next.count < 8) {
                    do { try store.changeMasterPassword(current: current, new: next); dismiss() }
                    catch { self.error = "현재 비밀번호가 올바르지 않습니다." }
                }
            }.padding(.top, 22)
        }
        .padding(24).frame(width: 400).background(t.surface)
    }
}

// MARK: Reissue recovery

struct ReissueRecoverySheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @State private var password = ""
    @State private var newKey: String?
    @State private var saved = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("복구 키 재발급").font(.sans(17, .bold)).foregroundStyle(t.ink)
            if let key = newKey {
                Text("새 복구 키입니다. 이전 키는 더 이상 쓸 수 없습니다.").font(.sans(12.5)).foregroundStyle(t.ink2).padding(.top, 6)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(RecoveryKey.grid(key), id: \.self) { g in
                        Text(g).font(.mono(17, .semibold)).kerning(1).foregroundStyle(t.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 7).fill(t.fill))
                    }
                }.padding(.top, 16)
                HStack {
                    GhostButton(title: "복사", icon: "copy", height: 28, hpad: 10, fontSize: 12) { store.copyToClipboard(key, title: "복구 키를 복사했습니다") }
                    Spacer()
                    AccentButton(title: "완료") { dismiss() }
                }.padding(.top, 16)
            } else {
                Text("현재 비밀번호를 확인한 뒤 새 복구 키를 발급합니다.").font(.sans(12.5)).foregroundStyle(t.ink2).padding(.top, 6)
                SecureField("비밀번호", text: $password).font(.mono(13)).frame(height: 34).fieldBG().padding(.top, 16)
                if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 8) }
                HStack {
                    Spacer()
                    GhostButton(title: "취소") { dismiss() }
                    AccentButton(title: "발급", disabled: password.isEmpty) {
                        do { newKey = try store.reissueRecoveryKey(masterPassword: password) }
                        catch { self.error = "비밀번호가 올바르지 않습니다." }
                    }
                }.padding(.top, 22)
            }
        }
        .padding(24).frame(width: 440).background(t.surface)
    }
}

// MARK: Reset confirm

struct ResetConfirmSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    var onDone: () -> Void
    @State private var confirm = ""
    @State private var password = ""
    @State private var error: String?

    private var canReset: Bool { confirm == "초기화" && !password.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 12).fill(t.dangerSoft).frame(width: 44, height: 44)
                .overlay(lucide("triangle-alert").font(.system(size: 20)).foregroundStyle(t.danger)).padding(.bottom, 14)
            Text("모든 데이터 초기화").font(.sans(17, .bold)).foregroundStyle(t.ink)
            Text("비밀번호와 모든 값을 영구히 지웁니다. 복구 키로도 되돌릴 수 없습니다. 계속하려면 아래에 초기화를 입력하고 비밀번호를 확인하세요.")
                .font(.sans(12.5)).foregroundStyle(t.ink2).lineSpacing(3).padding(.top, 6)
            TextField("초기화", text: $confirm).font(.sans(13)).frame(height: 34).fieldBG().padding(.top, 16)
            SecureField("비밀번호", text: $password).font(.mono(13)).frame(height: 34).fieldBG().padding(.top, 10)
            if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 8) }
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                Button {
                    guard store.verifyMasterPassword(password) else { error = "비밀번호가 올바르지 않습니다."; return }
                    store.resetEverything(); dismiss(); onDone()
                } label: {
                    Text("초기화").font(.sans(13, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 30)
                        .background(RoundedRectangle(cornerRadius: 7).fill(canReset ? t.danger : t.danger.opacity(0.5)))
                }.buttonStyle(.plain).disabled(!canReset)
            }.padding(.top, 22)
        }
        .padding(24).frame(width: 440).background(t.surface)
    }
}
