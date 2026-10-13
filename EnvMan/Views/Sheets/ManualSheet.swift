import SwiftUI

// MARK: Manual

/// An in-app manual, organized by feature, that embeds the app's real UI as
/// illustrations so each topic is easy to recognize. Can be deep-linked to a
/// specific topic (for example, the terminal-history topic from the copy panel).
struct ManualSheet: View {
    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store

    var initial: ManualTopic? = nil
    @State private var topic: ManualTopic = .overview

    // Local demo state for the live UI samples below.
    @State private var demoFormat: CopyFormat = .shell
    @State private var demoAppearance: Appearance = .system
    @State private var demoSession = 900
    @State private var demoLockOnSleep = true
    @State private var demoChecked = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(t.line).frame(height: 1)
            HStack(spacing: 0) {
                nav
                Rectangle().fill(t.line).frame(width: 1)
                content
            }
        }
        .frame(width: 760, height: 580)
        .background(t.surface)
        .onAppear { if let initial { topic = initial } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            lucide("book-open").font(.system(size: 15)).foregroundStyle(t.accent)
            Text("매뉴얼").font(.sans(17, .bold)).foregroundStyle(t.ink)
            Spacer()
            AccentButton(title: "완료", height: 28, hpad: 14, fontSize: 12.5) { dismiss() }
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
    }

    // MARK: Left nav

    private var nav: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ManualTopic.allCases) { tp in
                    ManualNavRow(topic: tp, active: tp == topic) { topic = tp }
                }
            }
            .padding(10)
        }
        .frame(width: 210)
        .background(t.side)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                h(topic.title)
                page
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 22, leading: 26, bottom: 30, trailing: 26))
        }
        .frame(maxWidth: .infinity)
        .id(topic) // reset scroll position when switching topics
    }

    @ViewBuilder private var page: some View {
        switch topic {
        case .overview: overview
        case .namespace: namespace
        case .secrets: secrets
        case .reveal: reveal
        case .copy: copyPage
        case .terminalHistory: terminalHistory
        case .share: share
        case .lock: lock
        case .password: password
        case .appearance: appearance
        }
    }

    // MARK: Pages

    @ViewBuilder private var overview: some View {
        p("EnvMan은 환경변수와 API 키를 이 Mac 안에서만 암호화해 보관합니다. 값은 네트워크로 보내지 않습니다.")
        preview("잠금 상태 표시") {
            HStack(spacing: 10) {
                stateBadge("lock", "잠김", t.ink2, t.fill)
                lucide("arrow-up-down").font(.system(size: 12)).foregroundStyle(t.ink3).rotationEffect(.degrees(90))
                stateBadge("lock-open", "열림", t.accentText, t.accentSoft)
            }
        }
        bullet("잠긴 상태에서도 네임스페이스와 키 이름, 메모는 볼 수 있습니다.")
        bullet("값을 보거나 복사하려면 비밀번호로 잠금을 해제합니다.")
        bullet("잠금을 해제하면 설정한 시간 동안 열려 있고, 그 뒤 자동으로 다시 잠깁니다.")
    }

    @ViewBuilder private var namespace: some View {
        p("프로젝트와 환경을 하나로 묶어 정리합니다. 사이드바에서 `프로젝트/환경` 형태로 만듭니다. (예: my-api/dev)")
        preview("사이드바 항목") {
            VStack(spacing: 6) {
                HStack {
                    Text("네임스페이스").font(.sans(11, .semibold)).foregroundStyle(t.ink3)
                    Spacer()
                    lucide("plus").font(.system(size: 13)).foregroundStyle(t.ink3)
                }
                fakeNsRow("my-api/dev", count: 8, active: true)
                fakeNsRow("web/prod", count: 12, active: false)
            }
        }
        bullet("새로 만들기: 상단의 + 버튼을 누르고 경로를 입력한 뒤 Enter를 누릅니다.")
        bullet("이름 변경, 위/아래 이동, 삭제: 선택한 항목 오른쪽의 … 메뉴에서 합니다.")
    }

    @ViewBuilder private var secrets: some View {
        p("키 이름과 값을 입력해 저장합니다. 키 이름은 대문자, 숫자, 언더바(\"_\")만 사용할 수 있습니다.")
        preview("값 입력") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "키 이름", color: t.ink2)
                    Text("DATABASE_URL").font(.mono(13)).foregroundStyle(t.ink).frame(maxWidth: .infinity, alignment: .leading).frame(height: 34).fieldBG()
                }
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "값", color: t.ink2)
                    Text("postgres://user:pass@host/db").font(.mono(13)).foregroundStyle(t.ink).frame(maxWidth: .infinity, alignment: .leading).frame(height: 34).fieldBG()
                }
            }
        }
        bullet("여러 줄 값도 그대로 입력할 수 있습니다.")
        bullet(".env 붙여넣기 탭을 쓰면 여러 키를 한 번에 추가할 수 있습니다.")
        callout("메모는 암호화되지 않습니다", "메모는 잠긴 상태에서도 보입니다. 비밀번호나 토큰 같은 민감한 값을 메모에 적지 마세요.", warn: false)
    }

    @ViewBuilder private var reveal: some View {
        p("잠금을 해제하면 각 항목의 값을 잠깐 보거나 클립보드로 복사할 수 있습니다.")
        preview("시크릿 행") {
            HStack(spacing: 10) {
                Text("STRIPE_SECRET_KEY").font(.mono(12.5, .medium)).foregroundStyle(t.ink)
                Spacer()
                Text(String(repeating: "•", count: 10)).font(.mono(12)).foregroundStyle(t.ink3)
                lucide("eye").font(.system(size: 13)).foregroundStyle(t.ink3)
                lucide("copy").font(.system(size: 13)).foregroundStyle(t.ink3)
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 8).fill(t.fill))
        }
        bullet("눈 아이콘으로 값을 잠깐 보고, 복사 아이콘으로 클립보드에 담습니다.")
        bullet("복사한 값은 설정한 시간 뒤 클립보드에서 자동으로 지워집니다.")
    }

    @ViewBuilder private var copyPage: some View {
        p("여러 항목을 체크해서 한 번에 복사할 수 있습니다. 형식은 .env, shell, JSON, gh 중에서 고릅니다.")
        preview("형식 선택") {
            VStack(alignment: .leading, spacing: 10) {
                Seg(options: CopyFormat.allCases.map { ($0, $0.label) }, selection: $demoFormat, mono: true)
                HStack(spacing: 8) {
                    CheckBox(on: demoChecked)
                    Text("DATABASE_URL").font(.mono(12.5)).foregroundStyle(t.ink)
                    Spacer()
                    GhostButton(title: "파일로 저장", icon: "file-down", height: 30, hpad: 10, fontSize: 12) {}
                    AccentButton(title: "복사", icon: "copy", height: 30, hpad: 12, fontSize: 12.5) {}
                }
            }
        }
        calloutButton(
            "값이 터미널 기록에 남을 수 있습니다",
            "shell과 gh 형식은 명령에 값이 그대로 들어갑니다. 터미널에 붙여넣어 실행하면 기록 파일에 남을 수 있습니다.",
            buttonTitle: "터미널 히스토리 삭제 방법",
            icon: "terminal"
        ) { topic = .terminalHistory }
    }

    @ViewBuilder private var terminalHistory: some View {
        callout("왜 중요한가요", "shell이나 gh 형식으로 복사한 명령에는 값이 평문으로 들어 있습니다. 터미널에 붙여넣어 실행하면 그 명령이 셸 기록 파일에 그대로 저장되어, 나중에 화살표 위 키나 기록 검색으로 다시 보일 수 있습니다.", warn: true)

        subhead("미리 막기")
        p("명령 맨 앞에 공백 한 칸을 넣으면 기록에 남지 않게 할 수 있습니다. 먼저 셸에서 아래 설정을 한 번 켜 둡니다.")
        bullet("zsh (macOS 기본): 아래를 실행하거나 ~/.zshrc 에 추가합니다.")
        codeBlock("setopt HIST_IGNORE_SPACE")
        bullet("bash: 아래를 실행하거나 ~/.bash_profile 에 추가합니다.")
        codeBlock("HISTCONTROL=ignorespace")
        p("설정을 켠 뒤에는 붙여넣은 명령 앞에 공백을 한 칸 두고 실행하면 그 줄은 기록되지 않습니다.")

        subhead("이미 실행했다면 (zsh, macOS 기본)")
        step(1, "값이 들어간 줄을 찾습니다.")
        codeBlock("grep -n \"지울값\" ~/.zsh_history")
        step(2, "기록 파일을 편집기로 열어 해당 줄을 지우고 저장합니다.")
        codeBlock("open -e ~/.zsh_history")
        step(3, "전체 기록을 모두 지우려면 파일을 비웁니다.")
        codeBlock(": > ~/.zsh_history")
        step(4, "지금 열려 있는 세션의 메모리 기록까지 비우려면 셸을 다시 시작합니다.")
        codeBlock("exec zsh")

        subhead("비웠는데도 ↑ 위 화살표로 계속 나와요 (zsh)")
        p("zsh는 지금 열려 있는 세션의 기록을 메모리에 따로 들고 있습니다. ~/.zsh_history 파일만 비워도 실행 중인 셸의 메모리에는 그대로 남아 있어서, 위 화살표를 누르면 다시 보입니다. 게다가 그 세션을 닫을 때 메모리의 기록을 파일에 다시 써 넣기 때문에, 비워 둔 파일이 도로 채워집니다. 그래서 아래 세 단계를 한 세션에서 함께 해야 합니다.")
        step(1, "기록 파일을 비웁니다.")
        codeBlock(": > ~/.zsh_history")
        step(2, "지금 세션의 메모리 기록을 비웁니다. zsh에는 bash의 history -c가 없으니, HISTSIZE를 0으로 줄였다가 원래 값으로 되돌립니다. (아래 10000은 평소 쓰던 값으로 바꾸세요.)")
        codeBlock("HISTSIZE=0 && HISTSIZE=10000")
        step(3, "셸을 새로 띄워 파일과 메모리를 맞춥니다.")
        codeBlock("exec zsh")
        bullet("파일만 비우고 2번을 건너뛴 채 세션을 그냥 닫으면, 닫는 순간 메모리 기록이 파일에 다시 써집니다.")

        subhead("iTerm2를 쓴다면 자체 기록도 확인하세요")
        p("iTerm2에 Shell Integration을 설치했다면, 위 화살표(셸 기록)와 별개로 iTerm2가 명령 기록을 따로 보관합니다. 자동완성 팝업이나 Command History 목록에서 값이 다시 보일 수 있습니다.")
        bullet("View 메뉴 > Toolbelt > Command History를 열어 해당 항목을 지우거나 목록을 비웁니다.")
        bullet("Settings > General에서 명령 기록을 디스크에 저장하는 옵션이 켜져 있는지 확인하세요. 저장 파일은 ~/Library/Application Support/iTerm2/ 아래에 있습니다.")
        bullet("화면에 보이는 출력(스크롤백)은 ⌘K로 지우고, 민감하면 탭이나 창을 닫으세요.")

        subhead("bash")
        bullet("특정 줄 삭제: history 로 번호(N)를 확인한 뒤 history -d N")
        bullet("현재 세션 메모리 기록 비우기: history -c")
        bullet("기록 파일 비우기 후 반영:")
        codeBlock(": > ~/.bash_history\nhistory -c")

        subhead("fish")
        bullet("특정 명령 삭제:")
        codeBlock("history delete --exact --case-sensitive \"지울 명령\"")
        bullet("전체 삭제: history clear")

        subhead("그 밖에")
        bullet("화면에 남은 출력(스크롤백)도 민감할 수 있습니다. 터미널 탭이나 창을 닫으면 사라집니다. (⌘K 로 화면 지우기)")
        bullet("클립보드는 설정한 시간 뒤 자동으로 비워집니다. (설정 > 세션과 클립보드)")
        bullet("iTerm2 같은 일부 터미널은 자체 기록이나 스크롤백을 따로 보관하므로, 그 터미널의 설정도 확인하세요.")
    }

    @ViewBuilder private var share: some View {
        p("다른 EnvMan으로 네임스페이스를 안전하게 옮길 수 있습니다. 내보낼 때 정한 공유 암호로 파일이 암호화되고, 받는 쪽에서는 그 암호로 연 뒤 자신의 비밀번호로 다시 암호화합니다.")
        preview("내보내기 단계") {
            HStack(spacing: 8) {
                stepChip(1, "네임스페이스")
                chevron
                stepChip(2, "공유 암호")
                chevron
                stepChip(3, "저장")
            }
        }
        bullet("공유 암호는 파일과 다른 경로(전화, 다른 메신저)로 전달하세요. 파일과 함께 보내면 보안상 취약합니다.")
        bullet("가져올 때는 파일을 고르고 공유 암호를 입력한 뒤, 내 비밀번호로 저장합니다.")
    }

    @ViewBuilder private var lock: some View {
        p("잠금을 해제하면 일정 시간 동안 열려 있습니다. 그 시간이 지나거나 아래 조건이 맞으면 자동으로 다시 잠깁니다.")
        preview("세션과 자동 잠금") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("세션 유지 시간").font(.sans(13)).foregroundStyle(t.ink)
                    Spacer()
                    Seg(options: AppSettings.sessionPresets.map { ($0.seconds, $0.label) }, selection: $demoSession, height: 24, fontSize: 12).fixedSize()
                }
                Button { demoLockOnSleep.toggle() } label: {
                    HStack {
                        Text("Mac이 절전에 들어가면 잠그기").font(.sans(13)).foregroundStyle(t.ink)
                        Spacer()
                        Switch(on: demoLockOnSleep)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        bullet("화면 잠금, 절전, 다른 앱으로 전환, 창 닫기 때 잠그도록 각각 켤 수 있습니다. (설정 > 자동 잠금)")
        bullet("사이드바 아래의 바로 잠그기(⌘L)로 언제든 즉시 잠글 수 있습니다.")
    }

    @ViewBuilder private var password: some View {
        p("비밀번호를 바꾸거나, 복구 키를 다시 발급하거나, 모든 데이터를 초기화할 수 있습니다. (설정 > 비밀번호와 복구)")
        preview("비밀번호와 복구") {
            HStack(spacing: 8) {
                GhostButton(title: "변경…", height: 28, hpad: 12, fontSize: 12.5) {}
                GhostButton(title: "재발급…", height: 28, hpad: 12, fontSize: 12.5) {}
                GhostButton(title: "초기화…", height: 28, hpad: 12, fontSize: 12.5, danger: true) {}
            }
        }
        bullet("비밀번호 변경: 현재 비밀번호를 확인한 뒤 새 비밀번호로 바꿉니다.")
        bullet("복구 키 재발급: 현재 비밀번호를 확인해야 새 키가 나오고, 이전 키는 바로 무효가 됩니다.")
        bullet("모든 데이터 초기화: 비밀번호와 모든 값을 영구히 지웁니다. 복구 키로도 되돌릴 수 없습니다.")
        callout("복구 키를 안전하게 보관하세요", "비밀번호를 잊으면 복구 키만이 값을 되살리는 유일한 방법입니다. EnvMan은 복구 키를 저장하지 않습니다.", warn: false)
    }

    @ViewBuilder private var appearance: some View {
        p("화면 외형을 시스템 설정에 맞추거나, 라이트 또는 다크 모드로 고정할 수 있습니다. (설정 > 모양)")
        preview("외형") {
            Seg(options: Appearance.allCases.map { ($0, $0.label) }, selection: $demoAppearance, height: 24, fontSize: 12).fixedSize()
        }
    }

    // MARK: Building blocks

    private func h(_ s: String) -> some View {
        Text(s).font(.sans(20, .bold)).foregroundStyle(t.ink)
    }

    private func subhead(_ s: String) -> some View {
        Text(s).font(.sans(14, .semibold)).foregroundStyle(t.ink).padding(.top, 6)
    }

    private func p(_ s: String) -> some View {
        Text(s).font(.sans(13)).foregroundStyle(t.ink2).lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").font(.sans(13)).foregroundStyle(t.ink3)
            Text(s).font(.sans(13)).foregroundStyle(t.ink2).lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func step(_ n: Int, _ s: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(n)").font(.sans(11, .bold)).foregroundStyle(t.accentInk)
                .frame(width: 18, height: 18)
                .background(Circle().fill(t.accent))
            Text(s).font(.sans(13)).foregroundStyle(t.ink2).lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 1)
        }
    }

    private func codeBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(text).font(.mono(12.5)).foregroundStyle(t.ink).textSelection(.enabled).lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.copyToClipboard(text, title: "명령을 복사했습니다") } label: {
                lucide("copy").font(.system(size: 12)).foregroundStyle(t.ink3)
            }.buttonStyle(.plain).help("복사")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(t.fill).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.line, lineWidth: 1)))
    }

    private func callout(_ title: String, _ body: String, warn: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            lucide(warn ? "triangle-alert" : "info").font(.system(size: 15)).foregroundStyle(warn ? t.warn : t.accent).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.sans(12.5, .semibold)).foregroundStyle(warn ? t.warn : t.ink)
                Text(body).font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(warn ? t.warnSoft : t.accentSoft).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(warn ? t.warnLine : t.accentRing, lineWidth: 1)))
    }

    private func calloutButton(_ title: String, _ body: String, buttonTitle: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            lucide("triangle-alert").font(.system(size: 15)).foregroundStyle(t.warn).padding(.top, 1)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.sans(12.5, .semibold)).foregroundStyle(t.warn)
                    Text(body).font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GhostButton(title: buttonTitle, icon: icon, height: 28, hpad: 12, fontSize: 12.5, action: action)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(t.warnSoft).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.warnLine, lineWidth: 1)))
    }

    private func preview<C: View>(_ caption: String, @ViewBuilder _ inner: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption.uppercased()).font(.sans(10, .semibold)).foregroundStyle(t.ink3).kerning(0.5)
            inner()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(t.win).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 1)))
        }
    }

    // Small static replicas used only inside previews.

    private func stateBadge(_ icon: String, _ label: String, _ ink: Color, _ bg: Color) -> some View {
        HStack(spacing: 6) {
            lucide(icon).font(.system(size: 12))
            Text(label).font(.sans(12, .semibold))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10).frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 7).fill(bg))
    }

    private func fakeNsRow(_ name: String, count: Int, active: Bool) -> some View {
        HStack(spacing: 8) {
            lucide("folder-lock").font(.system(size: 13)).foregroundStyle(active ? t.accent : t.ink3)
            Text(name).font(.mono(12.5, active ? .semibold : .regular)).foregroundStyle(t.ink)
            Spacer()
            Text("\(count)").font(.mono(11)).foregroundStyle(t.ink3)
            if active { lucide("ellipsis").font(.system(size: 13)).foregroundStyle(t.ink3) }
        }
        .padding(.horizontal, 10).frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 7).fill(active ? t.surface : .clear))
        .overlay(active ? RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.04), lineWidth: 1) : nil)
    }

    private func stepChip(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text("\(n)").font(.sans(10, .bold)).foregroundStyle(t.accentInk).frame(width: 16, height: 16).background(Circle().fill(t.accent))
            Text(label).font(.sans(12, .medium)).foregroundStyle(t.ink)
        }
        .padding(.horizontal, 10).frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 7).fill(t.fill))
    }

    private var chevron: some View {
        lucide("chevron-right").font(.system(size: 11)).foregroundStyle(t.ink3)
    }
}

/// A manual table-of-contents row with its own hover state.
private struct ManualNavRow: View {
    @Environment(\.theme) private var t
    let topic: ManualTopic
    let active: Bool
    let onSelect: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                lucide(topic.icon).font(.system(size: 13)).foregroundStyle(active ? t.accent : t.ink3).frame(width: 16)
                Text(topic.title).font(.sans(13, active ? .semibold : .regular)).foregroundStyle(t.ink)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(active ? t.surface : (hover ? t.hover : .clear)))
            .overlay(active ? RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.04), lineWidth: 1) : nil)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}
