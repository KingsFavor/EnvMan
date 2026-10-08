import SwiftUI

/// Exact color and shape tokens from the EnvMan design (light and dark), resolved
/// per color scheme. Names mirror the design's CSS variables.
struct Theme {
    let scheme: ColorScheme
    var isDark: Bool { scheme == .dark }

    private func c(_ light: String, _ dark: String) -> Color {
        Color(hex: isDark ? dark : light)
    }
    private func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    // Surfaces
    var page: Color { c("#ECEBE7", "#0F0F0E") }
    var win: Color { c("#FBFBFA", "#1B1B1A") }
    var side: Color { c("#F3F3F1", "#222220") }
    var surface: Color { c("#FFFFFF", "#2A2A28") }
    var field: Color { c("#FFFFFF", "#1F1F1E") }
    var fill: Color { c("#EDEDEA", "#2E2E2C") }

    // Lines
    var line: Color { c("#E7E6E2", "#333331") }
    var lineSoft: Color { c("#EFEEEB", "#2A2A28") }
    var lineStrong: Color { c("#D8D7D2", "#42423F") }

    // Ink
    var ink: Color { c("#1C1C1A", "#EDEDE9") }
    var ink2: Color { c("#5D5C57", "#AAA9A3") }
    var ink3: Color { c("#8D8C86", "#7C7B76") }
    var hover: Color { isDark ? rgba(255, 255, 255, 0.05) : rgba(28, 28, 26, 0.045) }

    // Accent
    var accent: Color { c("#2E7D64", "#4FB58C") }
    var accentInk: Color { c("#FFFFFF", "#0D1F17") }
    var accentSoft: Color { isDark ? rgba(79, 181, 140, 0.13) : Color(hex: "#E7F2ED") }
    var accentText: Color { c("#246A53", "#72CBA5") }
    var accentRing: Color { isDark ? rgba(79, 181, 140, 0.25) : rgba(46, 125, 100, 0.18) }

    // Warn
    var warn: Color { c("#8A5300", "#E8B062") }
    var warnSoft: Color { isDark ? rgba(232, 176, 98, 0.10) : Color(hex: "#FBF2E2") }
    var warnLine: Color { isDark ? rgba(232, 176, 98, 0.30) : Color(hex: "#EDD5A8") }

    // Danger
    var danger: Color { c("#BF3A2F", "#F0796D") }
    var dangerSoft: Color { isDark ? rgba(240, 121, 109, 0.12) : Color(hex: "#FBECEA") }

    // Scrim and toast
    var scrim: Color { isDark ? rgba(0, 0, 0, 0.45) : rgba(28, 28, 26, 0.18) }
    var toast: Color { c("#1E1E1C", "#EDEDE9") }
    var toastInk: Color { c("#F4F4F1", "#1C1C1A") }
    var toastInk2: Color { c("#A7A6A0", "#6A6964") }

    // macOS traffic lights (constant)
    var tlRed: Color { Color(hex: "#FF5F57") }
    var tlYellow: Color { Color(hex: "#FEBC2E") }
    var tlGreen: Color { Color(hex: "#28C840") }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(scheme: .light)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func provideTheme(_ scheme: ColorScheme) -> some View {
        environment(\.theme, Theme(scheme: scheme))
    }
}

/// Fonts. The design uses Pretendard for sans and JetBrains Mono for mono. We use
/// the native system fallbacks the design itself specifies (SF Pro and SF Mono),
/// keeping the app pure native.
extension Font {
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
