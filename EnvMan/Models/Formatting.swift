import Foundation

enum Formatting {
    /// "3개", "0개" style counts.
    static func count(_ n: Int) -> String { "\(n)개" }

    /// Remaining session time as "12:34" or "곧 잠김".
    static func remaining(until date: Date, now: Date = Date()) -> String {
        let secs = Int(date.timeIntervalSince(now).rounded(.down))
        if secs <= 0 { return "곧 잠김" }
        let m = secs / 60, s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    /// A short relative label for an edit time.
    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yy.MM.dd"
        return f.string(from: date)
    }
}
