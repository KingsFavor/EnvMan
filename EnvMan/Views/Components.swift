import SwiftUI

/// Top inset so content clears the real traffic lights under a hidden title bar.
let titleBarInset: CGFloat = 28

// MARK: Buttons

struct AccentButton: View {
    @Environment(\.theme) private var t
    let title: String
    var icon: String? = nil
    var shortcut: String? = nil
    var height: CGFloat = 30
    var hpad: CGFloat = 16
    var fontSize: CGFloat = 13
    var disabled: Bool = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { lucide(icon).font(.system(size: fontSize)) }
                Text(title).font(.sans(fontSize, .semibold))
                if let shortcut { Text(shortcut).font(.sans(fontSize - 1.5)).opacity(0.7) }
            }
            .foregroundStyle(t.accentInk)
            .padding(.horizontal, hpad)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.accent)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(hover && !disabled ? 0.1 : 0)))
            )
            .opacity(disabled ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hover = $0 }
    }
}

struct GhostButton: View {
    @Environment(\.theme) private var t
    let title: String
    var icon: String? = nil
    var height: CGFloat = 30
    var hpad: CGFloat = 14
    var fontSize: CGFloat = 13
    var danger: Bool = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { lucide(icon).font(.system(size: fontSize)).foregroundStyle(danger ? t.danger : t.ink2) }
                Text(title).font(.sans(fontSize, .medium)).foregroundStyle(danger ? t.danger : t.ink)
            }
            .padding(.horizontal, hpad)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hover ? t.hover : t.surface)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(danger ? t.danger : t.lineStrong, lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// A square icon button with a hover-fill look.
struct IconButton: View {
    @Environment(\.theme) private var t
    let icon: String
    var size: CGFloat = 28
    var fontSize: CGFloat = 14
    var help: String = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            lucide(icon).font(.system(size: fontSize))
                .foregroundStyle(hover ? t.ink : t.ink3)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hover ? t.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

// MARK: Segmented control

struct Seg<T: Hashable>: View {
    @Environment(\.theme) private var t
    let options: [(value: T, label: String)]
    @Binding var selection: T
    var mono: Bool = false
    var height: CGFloat = 26
    var fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                let on = opt.value == selection
                Button { selection = opt.value } label: {
                    Text(opt.label)
                        .font(mono ? .mono(fontSize, on ? .semibold : .medium) : .sans(fontSize, on ? .semibold : .medium))
                        .foregroundStyle(on ? t.ink : t.ink3)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(on ? t.surface : .clear)
                                .shadow(color: on ? .black.opacity(0.08) : .clear, radius: 1.5, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.fill))
    }
}

// MARK: Switch

struct Switch: View {
    @Environment(\.theme) private var t
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? t.accent : t.lineStrong).frame(width: 28, height: 16)
            Circle().fill(.white).frame(width: 12, height: 12).padding(2)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
        .frame(width: 28, height: 16)
    }
}

// MARK: Checkbox

struct CheckBox: View {
    @Environment(\.theme) private var t
    var on: Bool
    var partial: Bool = false
    var size: CGFloat = 14
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill((on || partial) ? t.accent : .clear)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder((on || partial) ? t.accent : t.lineStrong, lineWidth: 1))
            .frame(width: size, height: size)
            .overlay {
                if partial { lucide("minus").font(.system(size: size * 0.7, weight: .bold)).foregroundStyle(t.accentInk) }
                else if on { lucide("check").font(.system(size: size * 0.7, weight: .bold)).foregroundStyle(t.accentInk) }
            }
    }
}

// MARK: Chip

struct MonoChip: View {
    @Environment(\.theme) private var t
    let text: String
    var body: some View {
        Text(text).font(.mono(11))
            .foregroundStyle(t.ink2)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(t.fill))
    }
}

// MARK: Field styling

struct FieldBG: ViewModifier {
    @Environment(\.theme) private var t
    var focused: Bool = false
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.field)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(focused ? t.accent : t.lineStrong, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(t.accentRing, lineWidth: focused ? 3 : 0).padding(-1.5))
            )
    }
}

extension View {
    func fieldBG(_ focused: Bool = false) -> some View { modifier(FieldBG(focused: focused)) }
}

// MARK: Update banner

/// A slim, dismissible "update available" bar. No modal, no auto-download:
/// offers a copyable Homebrew command and a link to the release (DMG).
struct UpdateBanner: View {
    @Environment(\.theme) private var t
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        if updates.updateAvailable, let version = updates.latestVersion {
            HStack(spacing: 10) {
                lucide("sparkles").font(.system(size: 13)).foregroundStyle(t.accent)
                Text("새 버전 \(version) 사용 가능").font(.sans(12.5, .semibold)).foregroundStyle(t.ink)

                HStack(spacing: 6) {
                    Text(updates.updateCommand).font(.mono(11)).foregroundStyle(t.ink2)
                        .lineLimit(1).truncationMode(.tail)
                    Button { updates.copyCommand() } label: {
                        lucide(updates.commandCopied ? "check" : "copy").font(.system(size: 11))
                            .foregroundStyle(updates.commandCopied ? t.accent : t.ink2)
                    }
                    .buttonStyle(.plain).help("Homebrew 업데이트 명령 복사")
                }
                .padding(.horizontal, 8).frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(t.field).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.lineStrong, lineWidth: 1)))

                Spacer(minLength: 8)

                Button { updates.openReleasePage() } label: {
                    HStack(spacing: 4) {
                        Text("릴리즈 보기").font(.sans(12, .medium))
                        lucide("arrow-up-right").font(.system(size: 10))
                    }.foregroundStyle(t.accent)
                }.buttonStyle(.plain).help("릴리즈 페이지 열기 (DMG 직접 내려받기)")

                IconButton(icon: "x", size: 24, fontSize: 12, help: "이 버전 알림 숨기기") { updates.dismiss() }
            }
            .padding(.leading, 20).padding(.trailing, 10).frame(height: 40)
            .background(t.accentSoft)
            .overlay(alignment: .bottom) { Rectangle().fill(t.line).frame(height: 1) }
            .animation(.default, value: updates.commandCopied)
        }
    }
}

// MARK: Section label

struct FieldLabel: View {
    @Environment(\.theme) private var t
    let text: String
    var color: Color? = nil
    var body: some View {
        Text(text).font(.sans(11, .semibold)).foregroundStyle(color ?? t.ink3)
    }
}
