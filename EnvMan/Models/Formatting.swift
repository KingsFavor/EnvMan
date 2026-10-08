import Foundation

enum Formatting {
    static func count(_ n: Int) -> String { "\(n)개" }

    /// Relative edit time, matching the design: 오늘 / 어제 / N일 전 / N주 전 / N개월 전.
    static func ago(_ date: Date, now: Date = Date()) -> String {
        let days = Int(now.timeIntervalSince(date) / 86400)
        if days <= 0 { return "오늘" }
        if days == 1 { return "어제" }
        if days < 7 { return "\(days)일 전" }
        if days < 30 { return "\(days / 7)주 전" }
        return "\(days / 30)개월 전"
    }
}
