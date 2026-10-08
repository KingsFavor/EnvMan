import SwiftUI

/// Maps the design's lucide icon names to the closest SF Symbol, so icons render
/// natively while matching the design's intent.
func lucide(_ name: String) -> Image {
    Image(systemName: sfName(name))
}

private func sfName(_ name: String) -> String {
    switch name {
    case "hard-drive": return "internaldrive"
    case "lock-keyhole": return "lock.fill"
    case "clipboard-x": return "clipboard"
    case "clipboard-paste": return "doc.on.clipboard"
    case "shield-alert": return "exclamationmark.shield.fill"
    case "eye": return "eye"
    case "eye-off": return "eye.slash"
    case "lock": return "lock.fill"
    case "lock-open": return "lock.open.fill"
    case "folder-lock": return "folder.fill"
    case "plus": return "plus"
    case "ellipsis": return "ellipsis"
    case "pencil": return "pencil"
    case "arrow-up": return "arrow.up"
    case "arrow-down": return "arrow.down"
    case "arrow-up-down": return "arrow.up.arrow.down"
    case "trash-2": return "trash"
    case "chevron-right": return "chevron.right"
    case "chevron-down": return "chevron.down"
    case "search": return "magnifyingglass"
    case "search-x": return "magnifyingglass"
    case "share": return "square.and.arrow.up"
    case "upload": return "square.and.arrow.up"
    case "download": return "square.and.arrow.down"
    case "check": return "checkmark"
    case "copy": return "doc.on.doc"
    case "type": return "textformat"
    case "sticky-note": return "note.text"
    case "x": return "xmark"
    case "triangle-alert": return "exclamationmark.triangle.fill"
    case "circle-alert": return "exclamationmark.circle.fill"
    case "circle-check": return "checkmark.circle.fill"
    case "file-down": return "arrow.down.doc"
    case "file-lock-2": return "lock.doc"
    case "file-input": return "doc.badge.plus"
    case "settings": return "gearshape"
    case "printer": return "printer"
    case "message-square-lock": return "bubble.left.fill"
    case "minus": return "minus"
    default: return "questionmark"
    }
}
