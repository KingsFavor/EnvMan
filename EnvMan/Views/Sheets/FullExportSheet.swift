import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Exports or imports the entire vault as one encrypted file: every namespace
/// with its layout, folder color, `gh` form, memos and timestamps. This differs
/// from `ShareSheet`, which moves the keys of a single namespace. Used from
/// Settings → 데이터 to move a whole vault between installs.
struct FullExportSheet: View {
    enum Mode { case export, importFile }

    @Environment(\.theme) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var store

    let mode: Mode
    @State private var step = 0

    // export
    @State private var exPw = ""
    @State private var exSaved = false
    // import
    @State private var imData: Data?
    @State private var imName = ""
    @State private var imPw = ""
    @State private var imPayload: FullExportPayload?
    @State private var imResult: (namespaces: Int, secrets: Int)?
    @State private var error: String?

    private var steps: [String] {
        mode == .export ? ["확인과 암호", "저장"] : ["파일과 암호", "확인", "완료"]
    }

    var body: some View {
        VStack(spacing: 0) {
            headerStepper
            VStack(alignment: .leading, spacing: 0) { stepContent }
                .frame(minHeight: 210, alignment: .top)
                .padding(EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
            footer
        }
        .frame(width: 480)
        .background(t.surface)
    }

    private var headerStepper: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode == .export ? "전체 데이터 내보내기" : "전체 데이터 가져오기")
                .font(.sans(17, .bold)).foregroundStyle(t.ink)
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
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10).fill(t.fill).frame(width: 42, height: 42)
                    .overlay(lucide("database").font(.system(size: 20)).foregroundStyle(t.ink))
                VStack(alignment: .leading, spacing: 3) {
                    Text("네임스페이스 \(store.namespaceCount)개, 시크릿 \(store.totalSecretCount)개").font(.sans(13, .semibold)).foregroundStyle(t.ink)
                    Text("구성, 메모, 폴더 색, 명령 설정까지 통째로 담깁니다.").font(.sans(12)).foregroundStyle(t.ink2)
                }
                Spacer()
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 12).strokeBorder(t.line, lineWidth: 1)).padding(.bottom, 16)
            Text("파일을 여는 데 쓸 내보내기 암호입니다. 내 비밀번호와는 별개입니다.").font(.sans(12.5)).foregroundStyle(t.ink2).lineSpacing(2)
            SecureField("내보내기 암호", text: $exPw).font(.mono(13)).frame(height: 34).fieldBG().padding(.top, 12)
            StrengthBars(password: exPw).padding(.top, 8)
        default:
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10).fill(t.fill).frame(width: 42, height: 42)
                    .overlay(lucide("file-lock-2").font(.system(size: 20)).foregroundStyle(t.ink))
                VStack(alignment: .leading, spacing: 3) {
                    Text(FullExport.defaultFilename).font(.mono(13, .semibold)).foregroundStyle(t.ink)
                    Text("네임스페이스 \(store.namespaceCount)개, 시크릿 \(store.totalSecretCount)개, 암호로 암호화").font(.sans(12)).foregroundStyle(t.ink2)
                }
                Spacer()
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 12).strokeBorder(t.line, lineWidth: 1))
            if exSaved {
                HStack(spacing: 8) { lucide("circle-check").font(.system(size: 15)); Text("파일을 저장했습니다").font(.sans(13, .semibold)) }
                    .foregroundStyle(t.accentText).padding(.top, 14)
            }
            HStack(alignment: .top, spacing: 10) {
                lucide("message-square-lock").font(.system(size: 14)).foregroundStyle(t.ink2).padding(.top, 1)
                Text("내보내기 암호는 파일과 다른 경로로 전달하세요. 파일과 함께 보내면 보안 상 취약합니다.")
                    .font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(2)
            }
            .padding(.horizontal, 12).padding(.vertical, 10).padding(.top, 16)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.fill))
            if let error { Text(error).font(.sans(12)).foregroundStyle(t.danger).padding(.top, 10) }
        }
    }

    // MARK: Import

    @ViewBuilder private var importStep: some View {
        switch step {
        case 0:
            if imData == nil {
                Button { pickFile() } label: {
                    VStack(spacing: 8) {
                        lucide("file-input").font(.system(size: 24)).foregroundStyle(t.ink2)
                        Text("전체 데이터 파일을 선택하세요").font(.sans(13, .semibold)).foregroundStyle(t.ink)
                        Text("클릭해서 .envman 파일 선택").font(.sans(12)).foregroundStyle(t.ink3)
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
                Text("보낸 쪽에서 받은 내보내기 암호를 입력하세요.").font(.sans(12.5)).foregroundStyle(t.ink2).padding(.top, 16)
                SecureField("내보내기 암호", text: $imPw).font(.mono(13)).frame(height: 34).fieldBG().padding(.top, 10).onSubmit(decrypt)
                if let error { HStack(spacing: 6) { lucide("circle-alert").font(.system(size: 13)); Text(error).font(.sans(12)) }.foregroundStyle(t.danger).padding(.top, 8) }
            }
        case 1:
            HStack(alignment: .top, spacing: 10) {
                lucide("triangle-alert").font(.system(size: 14)).foregroundStyle(t.warn).padding(.top, 1)
                Text(replaceWarning).font(.sans(12)).foregroundStyle(t.ink2).lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 9).fill(t.warnSoft))
            .padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 0) {
                    let list = imPayload?.namespaces ?? []
                    ForEach(Array(list.enumerated()), id: \.offset) { i, ns in
                        HStack(spacing: 10) {
                            lucide("folder").font(.system(size: 13)).foregroundStyle(t.ink3)
                            Text(ns.path).font(.mono(12, .semibold)).foregroundStyle(t.ink)
                                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1).truncationMode(.middle)
                            Text("\(ns.secrets.count)개").font(.sans(11.5)).foregroundStyle(t.ink3)
                        }
                        .padding(.horizontal, 12).frame(height: 32)
                        .overlay(alignment: .bottom) { if i < list.count - 1 { Rectangle().fill(t.lineSoft).frame(height: 1) } }
                    }
                }
            }
            .frame(maxHeight: 190).background(RoundedRectangle(cornerRadius: 9).strokeBorder(t.line, lineWidth: 1))
        default:
            VStack(spacing: 12) {
                lucide("circle-check").font(.system(size: 26)).foregroundStyle(t.accent)
                Text(doneText).font(.sans(15, .semibold)).foregroundStyle(t.ink)
                Text("받은 파일은 더 이상 필요 없으니 지워도 됩니다.").font(.sans(12)).foregroundStyle(t.ink2)
            }.frame(maxWidth: .infinity, minHeight: 150)
        }
    }

    private var replaceWarning: String {
        guard let p = imPayload else { return "" }
        let current = store.vault?.namespaces.count ?? 0
        if current == 0 {
            return "네임스페이스 \(p.namespaces.count)개, 시크릿 \(p.secretCount)개를 가져옵니다."
        }
        return "기존 네임스페이스 \(current)개는 모두 지워지고, 파일의 네임스페이스 \(p.namespaces.count)개와 시크릿 \(p.secretCount)개로 교체됩니다."
    }

    private var doneText: String {
        guard let r = imResult else { return "가져오는 중" }
        return "네임스페이스 \(r.namespaces)개, 시크릿 \(r.secrets)개로 교체했습니다"
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
            case 0: return ("다음", exPw.count >= 6 && store.namespaceCount > 0)
            default: return exSaved ? ("완료", true) : ("파일로 저장", true)
            }
        } else {
            switch step {
            case 0: return ("복호화", imData != nil && imPw.count >= 1)
            case 1: return ("가져오기", imPayload != nil && !(imPayload?.namespaces.isEmpty ?? true))
            default: return ("완료", imResult != nil)
            }
        }
    }

    private func advance() {
        if mode == .export {
            switch step {
            case 0: step = 1
            default: if exSaved { dismiss() } else { saveExport() }
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
            let data = try store.exportFullData(password: exPw)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = FullExport.defaultFilename
            if let ty = UTType(filenameExtension: FullExport.fileExtension) { panel.allowedContentTypes = [ty] }
            panel.begin { resp in
                guard resp == .OK, let url = panel.url else { return }
                do { try data.write(to: url, options: .atomic); exSaved = true }
                catch { self.error = "파일을 저장하지 못했습니다." }
            }
        } catch { self.error = "내보내기에 실패했습니다." }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        if let ty = UTType(filenameExtension: FullExport.fileExtension) { panel.allowedContentTypes = [ty] }
        panel.allowsOtherFileTypes = true
        panel.begin { resp in
            guard resp == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            imData = data; imName = url.lastPathComponent; error = nil
        }
    }

    private func decrypt() {
        guard let data = imData else { return }
        do { imPayload = try store.previewFullImport(fileData: data, password: imPw); step = 1; error = nil }
        catch CryptoError.corrupted { self.error = "전체 데이터 파일이 아니거나 손상되었습니다." }
        catch { self.error = "내보내기 암호가 올바르지 않습니다." }
    }

    private func runImport() {
        guard let payload = imPayload else { return }
        do {
            imResult = try store.applyFullImport(payload)
            step = 2
        } catch { self.error = "가져오기에 실패했습니다." }
    }
}
