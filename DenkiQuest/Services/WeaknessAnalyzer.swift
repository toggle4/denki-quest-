import Foundation

/// 苦手マップの集計。単元ごとの得意・苦手を、学習記録（StudyRecord）と復習待ち（ReviewItem）から出す。
enum WeaknessAnalyzer {
    /// 直近この問題数ぶんの正答率で判定する（古い成績に引きずられないように）
    static let sampleSize = 30
    /// これより少ない回答数では判定しない
    static let minAnswers = 5
    /// 単元クリアの基準（CLAUDE.md の 90 %）に合わせる
    static let strongLine = 0.9
    static let weakLine = 0.7
    /// 出題形式を表すだけで、テーマとしては広すぎるタグ
    static let ignoredTags: Set<String> = ["計算", "概念"]
    /// 復習クエストは複数の単元が混ざるので、単元の成績には数えない
    static let excludedUnitIds: Set<String> = ["review"]

    enum Level {
        /// 正答率 70 % 未満
        case weak
        /// 70 % 以上 90 % 未満
        case almost
        /// 90 % 以上
        case strong
        /// 解いた数が少なく、まだ判定しない
        case few
        /// まだ解いていない
        case untried

        var label: String {
            switch self {
            case .weak: return "苦手"
            case .almost: return "もう少し"
            case .strong: return "得意"
            case .few: return "判定中"
            case .untried: return "未挑戦"
            }
        }
    }

    struct Entry: Identifiable {
        let unitId: String
        let title: String
        /// 直近の回答数（sampleSize 前後）と、そのうちの正解数
        let answered: Int
        let correct: Int
        /// 卒業していない復習待ちの問題数
        let pendingReviews: Int

        var id: String { unitId }

        var accuracy: Double? {
            answered > 0 ? Double(correct) / Double(answered) : nil
        }

        var level: Level {
            guard let accuracy else { return pendingReviews > 0 ? .few : .untried }
            if answered < WeaknessAnalyzer.minAnswers { return .few }
            if accuracy >= WeaknessAnalyzer.strongLine { return .strong }
            if accuracy >= WeaknessAnalyzer.weakLine { return .almost }
            return .weak
        }

        /// 「まず見直したい」順に並べるための値。小さいほど先
        var priority: Double {
            (accuracy ?? 1) - Double(min(pendingReviews, 10)) * 0.01
        }
    }

    struct TagCount: Identifiable {
        let tag: String
        let count: Int
        var id: String { tag }
    }

    /// units の単元ごとに集計する。records の並び順は問わない。
    static func entries(for units: [(id: String, title: String)], records: [StudyRecord], reviews: [ReviewItem]) -> [String: Entry] {
        let (answered, correct) = recentTotals(records)
        var pending: [String: Int] = [:]
        for item in reviews where !item.graduated {
            pending[item.unitId, default: 0] += 1
        }
        var result: [String: Entry] = [:]
        for unit in units {
            result[unit.id] = Entry(
                unitId: unit.id,
                title: unit.title,
                answered: answered[unit.id] ?? 0,
                correct: correct[unit.id] ?? 0,
                pendingReviews: pending[unit.id] ?? 0
            )
        }
        return result
    }

    /// 記録か復習待ちがある単元の ID（ホームのカード用）。
    static func touchedUnitIds(records: [StudyRecord], reviews: [ReviewItem]) -> [String] {
        var ids = Set(records.filter { $0.answeredCount > 0 }.map(\.unitId))
        ids.formUnion(reviews.filter { !$0.graduated }.map(\.unitId))
        return ids.subtracting(excludedUnitIds).sorted()
    }

    /// 単元ごとに、新しい記録から sampleSize 問に届くまで足し合わせる。
    private static func recentTotals(_ records: [StudyRecord]) -> ([String: Int], [String: Int]) {
        var answered: [String: Int] = [:]
        var correct: [String: Int] = [:]
        for record in records.sorted(by: { $0.startedAt > $1.startedAt }) where record.answeredCount > 0 {
            guard !excludedUnitIds.contains(record.unitId) else { continue }
            let sofar = answered[record.unitId, default: 0]
            guard sofar < sampleSize else { continue }
            answered[record.unitId] = sofar + record.answeredCount
            correct[record.unitId, default: 0] += min(record.correctCount, record.answeredCount)
        }
        return (answered, correct)
    }

    /// 復習待ちの問題のタグを、間違えた回数で重みづけして数える（新形式の問題だけタグがある）。
    static func weakTags(_ reviews: [ReviewItem], limit: Int = 8) -> [TagCount] {
        var counts: [String: Int] = [:]
        for item in reviews where !item.graduated {
            guard let question = QuestionBank.shared.question(id: item.questionId) else { continue }
            for tag in question.tags where !ignoredTags.contains(tag) {
                counts[tag, default: 0] += max(item.wrongCount, 1)
            }
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map { TagCount(tag: $0.key, count: $0.value) }
    }
}
