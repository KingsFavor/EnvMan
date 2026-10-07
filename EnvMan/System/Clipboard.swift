import AppKit

/// Copies to the pasteboard and, after a delay, clears the value if the pasteboard
/// still holds it. The write is marked as concealed so clipboard managers and
/// Universal Clipboard are asked not to retain or sync it.
@MainActor
enum Clipboard {
    private static var clearTask: Task<Void, Never>?

    static func copy(_ text: String, clearAfter seconds: Int) {
        let pb = NSPasteboard.general
        pb.clearContents()
        // Ask clipboard history tools to treat this as transient and concealed.
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pb.setString(text, forType: .string)

        clearTask?.cancel()
        guard seconds > 0 else { return }
        let changeCount = pb.changeCount
        clearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            if Task.isCancelled { return }
            // Only clear if nothing else has written since our copy.
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
