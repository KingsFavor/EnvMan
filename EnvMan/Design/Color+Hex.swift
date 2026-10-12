import SwiftUI
import AppKit

extension Color {
    /// Create a Color from a hex string like "#2E7D64" or "2E7D64" (RGB) or with alpha "AARRGGBB".
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch s.count {
        case 8: // AARRGGBB
            a = (value >> 24) & 0xff
            r = (value >> 16) & 0xff
            g = (value >> 8) & 0xff
            b = value & 0xff
        default: // RRGGBB
            a = 0xff
            r = (value >> 16) & 0xff
            g = (value >> 8) & 0xff
            b = value & 0xff
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    /// Returns an uppercase RRGGBB hex string (no alpha), or nil if conversion fails.
    func toHexRGB() -> String? {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(srgb.redComponent * 255))
        let g = Int(round(srgb.greenComponent * 255))
        let b = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// The default folder colors offered in the namespace color picker.
enum NamespacePalette {
    static let colors: [String] = [
        "#6B7280", // gray
        "#EF4444", // red
        "#F97316", // orange
        "#F59E0B", // amber
        "#84CC16", // lime
        "#10B981", // emerald
        "#14B8A6", // teal
        "#3B82F6", // blue
        "#8B5CF6", // violet
        "#EC4899", // pink
    ]
}
