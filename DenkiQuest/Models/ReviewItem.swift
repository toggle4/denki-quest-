import Foundation
import SwiftData

/// 間違えた問題の再出題スケジュール。1日→3日→7日→14日 と間隔を伸ばし、14 日後にも正解したら卒業。
@Model
final class ReviewItem {
    @Attribute(.unique) var questionId: String
    var unitId: String
    /// 0: 翌日、1: 3 日後、2: 7 日後、3: 14 日後
    var stage: Int
    var dueAt: Date
    var lastAnsweredAt: Date
    var wrongCount: Int
    var graduated: Bool

    init(questionId: String, unitId: String, now: Date = .now) {
        self.questionId = questionId
        self.unitId = unitId
        self.stage = 0
        self.dueAt = ReviewScheduler.nextDue(stage: 0, from: now)
        self.lastAnsweredAt = now
        self.wrongCount = 1
        self.graduated = false
    }
}

/// 回答結果を ReviewItem に反映する。
struct ReviewScheduler {
    static let intervalDays = [1, 3, 7, 14]

    let context: ModelContext

    static func nextDue(stage: Int, from now: Date) -> Date {
        let days = intervalDays[min(max(stage, 0), intervalDays.count - 1)]
        let calendar = Calendar.current
        // その日の朝 4 時を期限にすると「翌日」の感覚に合う
        let start = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: days, to: start) ?? now
        return calendar.date(byAdding: .hour, value: 4, to: day) ?? day
    }

    /// ドリルのコピー（"F02-t01#2"）は元の ID にそろえる。
    static func normalize(_ questionId: String) -> String {
        if let hash = questionId.firstIndex(of: "#") {
            return String(questionId[..<hash])
        }
        return questionId
    }

    func item(for questionId: String) -> ReviewItem? {
        let id = Self.normalize(questionId)
        let descriptor = FetchDescriptor<ReviewItem>(predicate: #Predicate { $0.questionId == id })
        return try? context.fetch(descriptor).first
    }

    /// 回答を記録する。どの画面（ドリル・教材・ボス戦）から呼んでもよい。
    func record(question: Question, unitId: String, correct: Bool, now: Date = .now) {
        let id = Self.normalize(question.id)
        let existing = item(for: id)

        if correct {
            guard let existing, !existing.graduated, existing.dueAt <= now else { return }
            existing.lastAnsweredAt = now
            existing.stage += 1
            if existing.stage >= Self.intervalDays.count {
                existing.graduated = true
            } else {
                existing.dueAt = Self.nextDue(stage: existing.stage, from: now)
            }
        } else {
            if let existing {
                existing.stage = 0
                existing.dueAt = Self.nextDue(stage: 0, from: now)
                existing.lastAnsweredAt = now
                existing.wrongCount += 1
                existing.graduated = false
            } else {
                context.insert(ReviewItem(questionId: id, unitId: unitId, now: now))
            }
        }
        LessonProgressStore.changes.bump()
    }
}

/// 復習待ちの ReviewItem から出題用の Question を組み立てる。
enum ReviewSessionBuilder {
    static func isDue(_ item: ReviewItem, now: Date = .now) -> Bool {
        !item.graduated && item.dueAt <= now
    }

    /// ID から問題を探す。新形式（template は数値を変えて生成）→ 旧形式の順。
    static func question(for questionId: String, units: [LearningUnit]) -> Question? {
        if let q = QuestionBank.shared.instantiate(id: questionId) { return q }
        for unit in units {
            if let q = unit.questions.first(where: { $0.id == questionId }) { return q }
        }
        return nil
    }

    static func dueQuestions(_ items: [ReviewItem], units: [LearningUnit], unitId: String? = nil, limit: Int = 10, now: Date = .now) -> [Question] {
        items
            .filter { isDue($0, now: now) && (unitId == nil || $0.unitId == unitId) }
            .sorted { $0.dueAt < $1.dueAt }
            .prefix(limit)
            .compactMap { question(for: $0.questionId, units: units) }
    }

    /// ホームの「復習」から始めるセッション用の単元。
    static func makeReviewUnit(_ items: [ReviewItem], units: [LearningUnit], now: Date = .now) -> LearningUnit? {
        let questions = dueQuestions(items, units: units, limit: 10, now: now)
        guard !questions.isEmpty else { return nil }
        return LearningUnit(
            id: "review",
            title: "復習クエスト",
            order: 0,
            stage: .review,
            description: "間違えた問題を 1→3→7→14 日の間隔で出し直す。",
            questions: questions,
            boss: nil
        )
    }
}
