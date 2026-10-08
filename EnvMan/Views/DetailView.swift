import SwiftUI

struct DetailView: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    private var namespace: NamespaceData? {
        guard let id = ui.selectedNamespace else { return nil }
        return store.namespace(id)
    }

    private var rows: [SecretData] {
        guard let ns = namespace else { return [] }
        var s = ns.secrets
        let q = ui.query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            s = s.filter { $0.key.lowercased().contains(q) || $0.memo.lowercased().contains(q) }
        }
        switch store.sortMode {
        case .keyAsc: s.sort { $0.key < $1.key }
        case .recent: s.sort { $0.updated > $1.updated }
        }
        return s
    }

    var body: some View {
        if namespace == nil {
            VStack { Spacer(); Text("네임스페이스를 선택하세요").font(.sans(14)).foregroundStyle(t.ink3); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(t.win)
        } else {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    Rectangle().fill(t.line).frame(height: 1)
                    if !store.isUnlocked { lockedBanner }
                    content
                }
                .frame(maxWidth: .infinity)
                if !ui.selected.isEmpty {
                    Rectangle().fill(t.line).frame(width: 1)
                    CopyPanel(namespaceID: ui.selectedNamespace!)
                }
            }
            .background(t.win)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            if let ns = namespace {
                HStack(spacing: 6) {
                    Text(ns.project).font(.mono(13)).foregroundStyle(t.ink3)
                    lucide("chevron-right").font(.system(size: 13)).foregroundStyle(t.ink3)
                    Text(ns.env).font(.sans(15, .semibold)).foregroundStyle(t.ink).lineLimit(1)
                    Text("\(ns.secrets.count)").font(.mono(11)).foregroundStyle(t.ink2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(t.fill))
                }
            }
            Spacer()
            searchBox
            sortMenu
            shareMenu
            GhostButton(title: "추가", icon: "plus", height: 28, hpad: 10, fontSize: 12) { openAdd() }
        }
        .padding(.leading, 20).padding(.trailing, 14)
        .frame(height: 52).padding(.top, 2)
    }

    private var searchBox: some View {
        @Bindable var ui = ui
        return HStack(spacing: 0) {
            lucide("search").font(.system(size: 13)).foregroundStyle(t.ink3).padding(.leading, 9).padding(.trailing, 6)
            TextField("키 이름이나 메모 검색", text: $ui.query).textFieldStyle(.plain).font(.sans(12))
            Text("⌘F").font(.sans(11)).foregroundStyle(t.ink3).padding(.trailing, 8)
        }
        .frame(width: 200, height: 28)
        .background(RoundedRectangle(cornerRadius: 7).fill(t.field).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.lineStrong, lineWidth: 1)))
    }

    private var sortMenu: some View {
        Menu {
            Button { store.sortMode = .keyAsc } label: { Label("키 이름", systemImage: store.sortMode == .keyAsc ? "checkmark" : "") }
            Button { store.sortMode = .recent } label: { Label("최근 수정", systemImage: store.sortMode == .recent ? "checkmark" : "") }
        } label: {
            HStack(spacing: 6) {
                lucide("arrow-up-down").font(.system(size: 13)).foregroundStyle(t.ink2)
                Text(store.sortMode == .keyAsc ? "키 이름" : "최근 수정").font(.sans(12, .medium)).foregroundStyle(t.ink)
            }
            .padding(.horizontal, 10).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 7).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.lineStrong, lineWidth: 1)))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }

    private var shareMenu: some View {
        Menu {
            Button("내보내기…") { requireUnlock { ui.sheet = .export } }
            Button("가져오기…") { requireUnlock { ui.sheet = .importFile } }
        } label: {
            HStack(spacing: 6) {
                lucide("share").font(.system(size: 13)).foregroundStyle(t.ink2)
                Text("공유").font(.sans(12, .medium)).foregroundStyle(t.ink)
            }
            .padding(.horizontal, 10).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 7).fill(t.surface).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.lineStrong, lineWidth: 1)))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }

    private var lockedBanner: some View {
        HStack(spacing: 10) {
            lucide("lock").font(.system(size: 14)).foregroundStyle(t.ink2)
            Text("값이 잠겨 있습니다. 키 이름과 메모는 비밀번호 없이 볼 수 있습니다.").font(.sans(13)).foregroundStyle(t.ink2)
            Spacer()
            AccentButton(title: "잠금 해제", height: 26, hpad: 12, fontSize: 12) {
                ui.sheet = .unlock(reason: "값을 보거나 복사하려면 마스터 비밀번호를 입력하세요.")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(t.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if let ns = namespace, ns.secrets.isEmpty {
            emptyNamespace
        } else if rows.isEmpty {
            noResult
        } else {
            VStack(spacing: 0) {
                tableHeader
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { secret in
                            SecretRow(namespaceID: ui.selectedNamespace!, secret: secret)
                            Rectangle().fill(t.lineSoft).frame(height: 1)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var allSelected: Bool { !rows.isEmpty && rows.allSatisfy { ui.selected.contains($0.id) } }
    private var someSelected: Bool { rows.contains { ui.selected.contains($0.id) } && !allSelected }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Button {
                if allSelected { rows.forEach { ui.selected.remove($0.id) } }
                else { rows.forEach { ui.selected.insert($0.id) } }
            } label: { CheckBox(on: allSelected, partial: someSelected) }
                .buttonStyle(.plain).frame(width: 20, alignment: .leading)
            Text("키").frame(maxWidth: .infinity, alignment: .leading)
            Text("값").frame(maxWidth: .infinity, alignment: .leading)
            Text("수정").frame(width: 56, alignment: .leading)
            Text(store.isUnlocked ? "두 번 눌러 복사" : "").frame(width: 150, alignment: .trailing).font(.sans(11))
        }
        .font(.sans(11, .semibold)).foregroundStyle(t.ink3)
        .padding(.leading, 20).padding(.trailing, 16).frame(height: 34)
        .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
    }

    private var emptyNamespace: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("BrandMark").renderingMode(.template).resizable().frame(width: 64, height: 64).foregroundStyle(t.ink3).opacity(0.7).padding(.bottom, 18)
            Text("아직 시크릿이 없습니다").font(.sans(15, .semibold)).foregroundStyle(t.ink)
            Text("키를 하나씩 추가하거나, .env 파일 내용을 붙여넣어 한 번에 가져오세요.")
                .font(.sans(13)).foregroundStyle(t.ink2).multilineTextAlignment(.center).lineSpacing(2).frame(width: 320).padding(.top, 6)
            HStack(spacing: 8) {
                AccentButton(title: "시크릿 추가", icon: "plus", height: 30, hpad: 12, fontSize: 12) { openAdd() }
                GhostButton(title: ".env 붙여넣기", icon: "clipboard-paste", height: 30, hpad: 12, fontSize: 12) { requireUnlock { ui.sheet = .paste } }
            }.padding(.top, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResult: some View {
        VStack(spacing: 0) {
            Spacer()
            lucide("search-x").font(.system(size: 28)).foregroundStyle(t.ink3).padding(.bottom, 14)
            Text("‘\(ui.query)’와 일치하는 키가 없습니다").font(.sans(15, .semibold)).foregroundStyle(t.ink)
            Text("키 이름과 메모에서 찾습니다.").font(.sans(13)).foregroundStyle(t.ink2).padding(.top, 6)
            GhostButton(title: "검색어 지우기", height: 28, hpad: 12, fontSize: 12) { ui.query = "" }.padding(.top, 18)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private func openAdd() { requireUnlock { ui.sheet = .add } }
    private func requireUnlock(_ action: @escaping () -> Void) {
        if store.isUnlocked { action() } else { ui.sheet = .unlock(reason: "값을 보거나 복사하려면 마스터 비밀번호를 입력하세요.") }
    }
}
