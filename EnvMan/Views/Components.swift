import SwiftUI

// MARK: Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    var disabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                    .fill(theme.accent.opacity(disabled ? 0.4 : (configuration.isPressed ? 0.85 : 1)))
            )
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                    .fill(theme.panel.opacity(configuration.isPressed ? 0.7 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.controlRadius, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
    }
}

// MARK: Card

struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                    .fill(theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                            .strokeBorder(theme.cardBorder, lineWidth: 1)
                    )
            )
    }
}

// MARK: Lock badge

struct LockBadge: View {
    @Environment(\.theme) private var theme
    var store: VaultStore

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: store.isUnlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(store.isUnlocked ? theme.accent : theme.locked)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(
            Capsule().fill((store.isUnlocked ? theme.accent : theme.locked).opacity(0.12))
        )
    }

    private var label: String {
        if store.isUnlocked, let expiry = store.sessionExpiry {
            return "해제 " + Formatting.remaining(until: expiry)
        }
        return store.isUnlocked ? "해제" : "잠김"
    }
}

// MARK: Section header

struct SectionLabel: View {
    @Environment(\.theme) private var theme
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.textMuted)
            .textCase(.uppercase)
            .kerning(0.4)
    }
}

// MARK: Empty state

struct EmptyHint: View {
    @Environment(\.theme) private var theme
    let systemImage: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(theme.textFaint)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
