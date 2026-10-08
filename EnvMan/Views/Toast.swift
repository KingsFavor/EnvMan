import SwiftUI

struct ToastView: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        if let toast = store.toast {
            ToastCard(toast: toast).id(toast.id)
        }
    }
}

private struct ToastCard: View {
    @Environment(\.theme) private var t
    @Environment(VaultStore.self) private var store
    let toast: VaultStore.Toast
    @State private var progress: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                lucide(toast.icon).font(.system(size: 16)).foregroundStyle(t.toastInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text(toast.title).font(.sans(13, .semibold)).foregroundStyle(t.toastInk).lineLimit(1)
                    if let sub = toast.sub {
                        Text(sub).font(.sans(11.5)).foregroundStyle(t.toastInk2).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if toast.kind == .clip {
                    toastButton("지금 지우기") { store.clearClipboardNow() }
                } else if toast.kind == .undo {
                    toastButton("실행 취소") { toast.undo?() }
                }
            }
            .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 12)

            if toast.kind == .clip {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 3)
                        Rectangle().fill(t.accent).frame(width: geo.size.width * progress, height: 3)
                    }
                }.frame(height: 3)
            }
        }
        .frame(width: 400)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.toast))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 16)
        .padding(.bottom, 22)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear(perform: startBar)
    }

    private func startBar() {
        guard toast.kind == .clip, let start = toast.clipStart, let end = toast.clipEnd else { return }
        let total = end.timeIntervalSince(start)
        let remaining = max(0, end.timeIntervalSinceNow)
        // Jump to the current fraction without animation, then shrink to 0 linearly.
        var instant = Transaction(); instant.disablesAnimations = true
        withTransaction(instant) { progress = total > 0 ? CGFloat(remaining / total) : 0 }
        withAnimation(.linear(duration: remaining)) { progress = 0 }
    }

    private func toastButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.sans(11.5, .semibold)).foregroundStyle(t.toastInk)
                .padding(.horizontal, 10).frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 7).strokeBorder(t.toastInk2, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
