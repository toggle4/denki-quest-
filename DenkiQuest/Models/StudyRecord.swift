import Foundation
import SwiftData

/// 1 回のクエスト（セッション）の学習記録。SwiftData に保存する。
@Model
final class StudyRecord {
    var startedAt: Date
    var durationSeconds: Double
    var unitId: String
    var answeredCount: Int
    var correctCount: Int
    var completed: Bool

    init(
        startedAt: Date,
        durationSeconds: Double,
        unitId: String,
        answeredCount: Int,
        correctCount: Int,
        completed: Bool
    ) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.unitId = unitId
        self.answeredCount = answeredCount
        self.correctCount = correctCount
        self.completed = completed
    }
}

/// 学習時間の目標値。
enum StudyGoal {
    /// 合格の目安となる総学習時間
    static let targetHours: Double = 200
    /// ここまで来れば安心、というライン
    static let safeHours: Double = 150
    /// 1 記録あたりの上限（アプリを開きっぱなしにしても水増しされない）
    static let maxSecondsPerRecord: Double = 30 * 60
    /// これより短い中断は記録しない
    static let minSecondsToRecord: Double = 10
}

/// 記録の集計結果。
struct StudyStats {
    struct Day: Identifiable {
        let date: Date
        let seconds: Double
        var id: Date { date }
    }

    let totalSeconds: Double
    let todaySeconds: Double
    let streakDays: Int
    let last7Days: [Day]
    let sessionCount: Int

    var totalHours: Double { totalSeconds / 3600 }

    init(records: [StudyRecord], calendar: Calendar = .current, now: Date = .now) {
        let today = calendar.startOfDay(for: now)

        var perDay: [Date: Double] = [:]
        var total: Double = 0
        for record in records {
            total += record.durationSeconds
            let day = calendar.startOfDay(for: record.startedAt)
            perDay[day, default: 0] += record.durationSeconds
        }

        totalSeconds = total
        todaySeconds = perDay[today] ?? 0
        sessionCount = records.count

        // 連続日数: 今日（まだ学習していなければ昨日）から遡って途切れるまで数える
        var streak = 0
        var cursor = perDay[today] != nil ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        while let seconds = perDay[cursor], seconds > 0 {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        streakDays = streak

        last7Days = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return Day(date: day, seconds: perDay[day] ?? 0)
        }
    }
}

/// 学習時間の表示用フォーマット。
enum StudyFormat {
    /// "12.5" のように時間を小数 1 桁で
    static func hours(_ seconds: Double) -> String {
        String(format: "%.1f", seconds / 3600)
    }

    /// "1 時間 5 分" / "25 分" / "40 秒"
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h) 時間 \(m) 分" }
        if m > 0 { return "\(m) 分" }
        return "\(s) 秒"
    }

    /// "03:24" のようなタイマー表示
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
