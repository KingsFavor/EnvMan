import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShareSheet: View {
    enum Mode { case export, importFile }

    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store
    @Environment(UIState.self) private var ui

    let mode: Mode
    @State private var step = 0

    // export
    @State private var exSelected: Set<UUID> = []
    @State private var exPw = ""
    @State private var exSaved = false
    // import
    @State private var imData: Data?
    @State private var imName = ""
    @State private var imPw = ""
    @State private var imPayload: SharePayload?
    @State private var imTarget: UUID?
    @State private var imPolicy: VaultStore.ConflictPolicy = .keepBoth
    @State private var imDone = false
    @State private var error: String?

    private var steps: [String] { mode == .export ? ["네임스페이스", "공유 암호", "저장"] : ["파일과 암호", "확인", "완료"] }

    var body: some View {
        VStack(spacing: 0) {
            headerStepper
            VStack(alignment: .leading, spacing: 0) { stepContent }
                .frame(minHeight: 200, alignment: .top)
                .padding(EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
            footer
        }
        .frame(width: 480)
        .background(t.surface)
        .onAppear {
            if mode == .export, let cur = ui.selectedNamespace { exSelected = [cur] }
            if mode == .importFile { imTarget = ui.selectedNamespace ?? store.vault?.namespaces.first?.id }
        }
    }

    private var headerStepper: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode == .export ? "암호화 내보내기" : "암호화 가져오기").font(.sans(17, .bold)).foregroundStyle(t.ink)
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, label in
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().fill(i == step ? t.accent : t.fill).overlay(Circle().strokeBorder(i == step ? .clear : t.lineStrong, lineWidth: 1)).frame(width: 18, height: 18)
                            Text("\(i + 1)").font(.sans(10.5, .semibold)).foregroundStyle(i == step ? t.accentInk : t.ink3)
                        }
                        Text(label).font(.sans(12, i == step ? .semibold : .regular)).foregroundStyle(i == step ? t.ink : t.ink3)
                        if i < steps.count - 1 { Rectangle().fill(t.lineStrong).frame(width: 18, height: 1).padding(.horizontal, 2) }
                    }
                }
            }.padding(.top, 14)
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 16, trailing: 24))
        .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
    }

    @ViewBuilder private var stepContent: some View {
        if mode == .export { exportStep } else { importStep }
    }

    // MARK: Export

    @ViewBuilder private var exportStep: some View {
        switch step {
        case 0:
            Text("파일에 담을 네임스페이스를 고르세요.").font(.sans(12.5)).foregroundStyle(t.ink2).padding(.bottom, 12)
            VStack(spacing: 0) {
                ForEach(Array((store.vault?.namespaces ?? []).enumerated()), id: \.element.id) { i, ns in
                    Button {
                        if exSelected.contains(ns.id) { exSelected.remove(ns.id) } else { exSelected.insert(ns.id) }
                    } label: {
                        HStack(spacing: 10) {
                            CheckBox(on: exSelected.contains(ns.id))
                            Text(ns.path).font(.mono(12)).foregroundStyle(t.ink)
                            Spacer()
                            Text("\(ns.secrets.count)개").font(.sans(11.5)).foregroundStyle(t.ink3)
                        }
                        .padding(.horizontal, 12).frame(height: 34).contentShape(Rectangle())
                        .overlay(alignment: .top) { if i > 0 { Rectangle().fill(t.lineSoft).frame(height: 1) } }
                    }.buttonStyle(.plain)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 1))
        case 1:
            Text("받는 사람이 파일을 열 때 쓸 암호입니다. 내 마스터 비밀번호와는 별개입니다.").font(.sans(12.5)).foregroundStyle(t.ink2).lineSpacing(2)
            SecureField("공유 암호", text: $exPw).font(.mono(13)).frame(height: 34).fieldBG().padding(.top, 14)
            StrengthBars(password: exPw).padding(.top, 8)
            HStack(alignment: .top, spacing: 10) {
                lucide("message-square-lock").font(.system(size: 14)).foregroundStyle(t.ink2).padding(.top, 1)
                Text("암호는 파일과 다른 경로(전화, 다른 메신저)로 전달하세요. 같은 대화방에 함께 보내면 암호화의 의미가 줄어듭니다.")
                    .font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(2)
            }
            .padding(.horizontal, 12).padding(.vertical, 10).padding(.top, 16)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.fill))
        default:
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10).fill(t.fill).frame(width: 42, height: 42)
                    .overlay(lucide("file-lock-2").font(.system(size: 20)).foregroundStyle(t.ink))
                VStack(alignment: .leading, spacing: 3) {
                    Text(exFilename).font(.mono(13, .semibold)).foregroundStyle(t.ink)
                    Text("\(exTotalCount)개 시크릿, 공유 암호로 암호화").font(.sans(12)).foregroundStyle(t.ink2)
                }
                Spacer()
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 12).strokeBorder(t.line, lineWidth: 1))
            if exSaved {
                HStack(spacing: 8) { lucide("circle-check").font(.system(size: 15)); Text("파일을 저장했습니다").font(.sans(13, .semibold)) }
                    .foregroundStyle(t.accentText).padding(.top, 14)
            }
            if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 10) }
        }
    }

    private var exFilename: String {
        if exSelected.count == 1, let ns = store.namespace(exSelected.first!) {
            return ns.path.replacingOccurrences(of: "/", with: "-") + ".envman"
        }
        return "envman-export.envman"
    }
    private var exTotalCount: Int {
        exSelected.reduce(0) { $0 + (store.namespace($1)?.secrets.count ?? 0) }
    }

    // MARK: Import

    @ViewBuilder private var importStep: some View {
        switch step {
        case 0:
            if imData == nil {
                Button { pickFile() } label: {
                    VStack(spacing: 8) {
                        lucide("file-input").font(.system(size: 24)).foregroundStyle(t.ink2)
                        Text(".envman 파일을 선택하세요").font(.sans(13, .semibold)).foregroundStyle(t.ink)
                        Text("클릭해서 파일 선택").font(.sans(12)).foregroundStyle(t.ink3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5])).foregroundStyle(t.lineStrong))
                }.buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    lucide("file-lock-2").font(.system(size: 15)).foregroundStyle(t.ink2)
                    Text(imName).font(.mono(12, .semibold)).foregroundStyle(t.ink)
                    Spacer()
                    Button("다른 파일") { imData = nil; imPayload = nil }.buttonStyle(.plain).font(.sans(11.5)).foregroundStyle(t.accentText)
                }
                .padding(.horizontal, 12).frame(height: 40).background(RoundedRectangle(cornerRadius: 9).fill(t.fill))
                Text("보낸 사람에게 받은 공유 암호를 입력하세요.").font(.sans(12.5)).foregroundStyle(t.ink2).padding(.top, 16)
                SecureField("공유 암호", text: $imPw).font(.mono(13)).frame(height: 34).fieldBG().padding(.top, 10).onSubmit(decrypt)
                if let error { HStack(spacing: 6) { lucide("circle-alert").font(.system(size: 13)); Text(error).font(.sans(12)) }.foregroundStyle(t.danger).padding(.top, 8) }
            }
        case 1:
            FieldLabel(text: "가져올 네임스페이스").padding(.bottom, 6)
            Picker("", selection: Binding(get: { imTarget ?? store.vault?.namespaces.first?.id }, set: { imTarget = $0 })) {
                ForEach(store.vault?.namespaces ?? []) { ns in Text(ns.path).tag(Optional(ns.id)) }
            }.labelsHidden().font(.mono(12))
            HStack {
                Text(importSummary).font(.sans(12)).foregroundStyle(t.ink2)
                Spacer()
                Seg(options: [(VaultStore.ConflictPolicy.overwrite, "덮어쓰기"), (.skip, "건너뛰기"), (.keepBoth, "둘 다")], selection: $imPolicy, height: 22, fontSize: 11.5).fixedSize()
            }.padding(.top, 16)
            VStack(spacing: 0) {
                ForEach(Array((imPayload?.secrets ?? []).prefix(50).enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 10) {
                        Text(s.key).font(.mono(12, .semibold)).foregroundStyle(t.ink).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                        importBadge(s.key)
                    }
                    .padding(.horizontal, 12).frame(height: 30)
                    .overlay(alignment: .bottom) { Rectangle().fill(t.lineSoft).frame(height: 1) }
                }
            }
            .frame(maxHeight: 170).background(RoundedRectangle(cornerRadius: 9).strokeBorder(t.line, lineWidth: 1)).padding(.top, 8)
        default:
            VStack(spacing: 12) {
                lucide("circle-check").font(.system(size: 26)).foregroundStyle(t.accent)
                Text(imDone ? "\(imPayload?.secrets.count ?? 0)개를 가져왔습니다" : "가져오는 중").font(.sans(15, .semibold)).foregroundStyle(t.ink)
                Text("받은 파일은 더 이상 필요 없으니 지워도 됩니다.").font(.sans(12)).foregroundStyle(t.ink2)
            }.frame(maxWidth: .infinity, minHeight: 150)
        }
    }

    private var importSummary: String {
        guard let p = imPayload else { return "" }
        let dup = p.secrets.filter { s in (store.namespace(imTarget ?? UUID())?.secrets.contains { $0.key == s.key }) ?? false }.count
        return "\(p.secrets.count)개 중 신규 \(p.secrets.count - dup)개, 중복 \(dup)개"
    }
    private func importBadge(_ key: String) -> some View {
        let dup = (store.namespace(imTarget ?? UUID())?.secrets.contains { $0.key == key }) ?? false
        let (text, bg, fg): (String, Color, Color) = dup
            ? (imPolicy == .skip ? ("건너뜀", t.fill, t.ink3) : (imPolicy == .overwrite ? ("덮어씀", t.warnSoft, t.warn) : ("새 이름", t.accentSoft, t.accentText)))
            : ("신규", t.accentSoft, t.accentText)
        return Text(text).font(.sans(11, .semibold)).foregroundStyle(fg).padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(bg))
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            GhostButton(title: step == 0 ? "취소" : "이전") { if step == 0 { dismiss() } else { step -= 1; error = nil } }
            Spacer()
            if let (label, enabled) = nextButton {
                AccentButton(title: label, disabled: !enabled) { advance() }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 24, bottom: 18, trailing: 24))
        .overlay(alignment: .top) { Rectangle().fill(t.line).frame(height: 1) }
    }

    private var nextButton: (String, Bool)? {
        if mode == .export {
            switch step {
            case 0: return ("다음", !exSelected.isEmpty)
            case 1: return ("만들기", exPw.count >= 6)
            default: return exSaved ? ("완료", true) : ("파일로 저장", true)
            }
        } else {
            switch step {
            case 0: return ("복호화", imData != nil && imPw.count >= 1)
            case 1: return ("가져오기", imTarget != nil)
            default: return ("완료", imDone)
            }
        }
    }

    private func advance() {
        if mode == .export {
            switch step {
            case 0, 1: step += 1
            default:
                if exSaved { dismiss() } else { saveExport() }
            }
        } else {
            switch step {
            case 0: decrypt()
            case 1: runImport()
            default: dismiss()
            }
        }
    }

    // MARK: Actions

    private func saveExport() {
        do {
            var all: [PlainSecret] = []
            for id in exSelected { all += try store.plainSecrets(namespaceID: id, ids: nil) }
            let label = exSelected.count == 1 ? (store.namespace(exSelected.first!)?.path ?? "export") : "\(exSelected.count)개 네임스페이스"
            let data = try ShareBundle.export(namespace: label, secrets: all, password: exPw)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = exFilename
            if let ty = UTType(filenameExtension: ShareBundle.fileExtension) { panel.allowedContentTypes = [ty] }
            panel.begin { resp in
                guard resp == .OK, let url = panel.url else { return }
                try? data.write(to: url, options: .atomic)
                exSaved = true
            }
        } catch { self.error = "내보내기에 실패했습니다." }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        if let ty = UTType(filenameExtension: ShareBundle.fileExtension) { panel.allowedContentTypes = [ty] }
        panel.allowsOtherFileTypes = true
        panel.begin { resp in
            guard resp == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            imData = data; imName = url.lastPathComponent; error = nil
        }
    }

    private func decrypt() {
        guard let data = imData else { return }
        do { imPayload = try store.previewImport(fileData: data, sharePassword: imPw); step = 1; error = nil }
        catch { self.error = "공유 암호가 올바르지 않습니다." }
    }

    private func runImport() {
        guard let payload = imPayload, let target = imTarget else { return }
        do {
            try store.applyImport(payload, into: target, policy: imPolicy)
            imDone = true; step = 2
        } catch { self.error = "가져오기에 실패했습니다." }
    }
}

struct StrengthBars: View {
    @Environment(\.theme) private var t
    let password: String
    private var score: Int {
        var s = 0
        if password.count >= 6 { s += 1 }
        if password.count >= 10 { s += 1 }
        if password.contains(where: \.isNumber) && password.contains(where: \.isLetter) { s += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { s += 1 }
        return min(4, s)
    }
    private var label: (String, Color) {
        switch score { case 0, 1: return ("약함", t.danger); case 2: return ("보통", t.warn); default: return ("강함", t.accentText) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in RoundedRectangle(cornerRadius: 2).fill(i < score ? label.1 : t.lineStrong).frame(height: 4) }
            }
            if !password.isEmpty { Text(label.0).font(.sans(12, .semibold)).foregroundStyle(label.1) }
        }
    }
}
